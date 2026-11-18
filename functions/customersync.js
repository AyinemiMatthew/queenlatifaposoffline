const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

if (!getApps().length) initializeApp();
const db = getFirestore();

const CUSTOMERS_API_URL = 'https://queenlatifahenterprise.com/pos/firebase/customers';
// ASSUMED name, following your trans_callback / itemreg_callback pattern. Confirm it.
const CUSTOMERS_CALLBACK_URL = 'https://queenlatifahenterprise.com/pos/firebase/customers_callback';
const CUSTOMERS_COLLECTION = 'customers';

const str = (v) => (v ?? '').toString().trim();
const slug = (s) => str(s).toLowerCase().replace(/[^a-z0-9]/g, '');
const capitalize = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1) : '');
/**
 * Builds a safe key from the contact field.
 * "0241066824 / 0248327017" -> "0241066824"
 * Falls back to the slugged name when there is no usable contact.
 */
function contactKey(contact, name) {
  const first = str(contact)
    .split(/[\/,;|]|\s+(?:or|and)\s+/i)[0]   // first of several numbers
    .replace(/[^a-zA-Z0-9]/g, '');            // no spaces, slashes, dots, etc.
  return first || slug(name);
}
/** Pulls the JSON out of a response that may have PHP notices around it. */
function extractJson(text) {
  const m = text.match(/\{[\s\S]*\}/);
  if (!m) return null;
  try { return JSON.parse(m[0]); } catch (_) { return null; }
}

async function getJson(url) {
  let lastErr;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(url, {
        headers: { Accept: 'application/json' },
        signal: AbortSignal.timeout(60000),
      });
      const text = await res.text();
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const body = extractJson(text);
      if (!body) throw new Error('No JSON in response');
      if (body.success === false) throw new Error(body.message || 'API reported failure');
      return body;
    } catch (e) {
      lastErr = e;
      if (attempt < 3) await new Promise((r) => setTimeout(r, attempt * 1500));
    }
  }
  throw new Error(`Customers API failed: ${lastErr.message}`);
}

/** Fetches everything first, so acknowledging can't change the paging. */
async function fetchAllCustomers() {
  const first = await getJson(CUSTOMERS_API_URL);
  const all = Array.isArray(first.data) ? [...first.data] : [];
  const totalPages = Number(first.total_pages) || 1;

  for (let page = 2; page <= totalPages; page++) {
    const body = await getJson(`${CUSTOMERS_API_URL}?page=${page}`);
    if (!Array.isArray(body.data) || body.data.length === 0) break;
    all.push(...body.data);
  }

  // De-duplicate by source id in case pages overlap
  const seen = new Set();
  return all.filter((r) => {
    const id = str(r.id);
    if (!id || seen.has(id)) return false;
    seen.add(id);
    return true;
  });
}

function parseCreated(date, time) {
  const d = str(date);
  if (!d) return Timestamp.now();
  const t = str(time);
  const parsed = new Date(t ? `${d}T${t}Z` : `${d}T00:00:00Z`);
  return isNaN(parsed.getTime()) ? Timestamp.now() : Timestamp.fromDate(parsed);
}

/** Fields the endpoint owns. Written on every sync. */
function mapSourceFields(r, company) {
  const contact = str(r.contact);
  const key = contactKey(contact, r.name);
  const name = str(r.name);
  const branchname = str(r.branch);

  return {
    id: `${company.companyid.toLowerCase()}_${key}`,
    sourceid: str(r.id),
    name,
    namelower: name.toLowerCase(),
    contact,
    companyid: company.companyid,
    companyname: company.companyname,
    branchname,
    branchid: branchname ? `${company.companyid.toLowerCase()}${slug(branchname)}` : '',
    customertype: capitalize(str(r.category).toLowerCase()) || 'Cash',
    creditlimit: str(r.creditlimit) || '0',
    paymentduration: capitalize(str(r.payment_duration).toLowerCase()),
    pricingtype: str(r.pricing_type),
    accountnumber: str(r.accountnumber),
    staff: str(r.staff),
    updatedat: FieldValue.serverTimestamp(),
    updatedby: 'customersync',
  };
}

/** Only on first creation, so live balances are never overwritten. */
const newDocDefaults = (r) => ({
  amountpaid: '0',
  creditBalance: str(r.balance) || '0',
  createdat: parseCreated(r.date, r.time),
  date: parseCreated(r.date, r.time),
  deletedat: null,
  deletedby: null,
});

async function acknowledge(ids) {
  let requested = 0;
  let updated = 0;
  for (let i = 0; i < ids.length; i += 100) {
    const chunk = ids.slice(i, i + 100);
    const res = await fetch(CUSTOMERS_CALLBACK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ ids: chunk }),
      signal: AbortSignal.timeout(30000),
    });
    const text = await res.text();
    if (!res.ok) throw new Error(`Callback HTTP ${res.status}: ${text.slice(0, 200)}`);
    const parsed = extractJson(text);
    if (!parsed || parsed.success !== true) {
      throw new Error(`Callback failed: ${parsed?.message || text.slice(0, 200)}`);
    }
    requested += Number(parsed.requested) || chunk.length;
    updated += Number(parsed.updated) || 0;
  }
  return { requested, updated };
}

exports.syncCustomers = onCall(
  { region: 'us-central1', timeoutSeconds: 300, memory: '512MiB' },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');

    // Company comes from the caller's staff record, not from the client
    const email = str(req.auth.token.email).toLowerCase();
    const staffSnap = await db.collection('staff').doc(email).get();
    if (!staffSnap.exists) {
      throw new HttpsError('permission-denied', 'No staff record for this user.');
    }
    const staff = staffSnap.data();
    const company = {
      companyid: str(staff.companyid),
      companyname: str(staff.company),
    };
    if (!company.companyid) {
      throw new HttpsError('failed-precondition', 'Staff record has no company.');
    }

    let records;
    try {
      records = await fetchAllCustomers();
    } catch (e) {
      console.error(e);
      throw new HttpsError('unavailable', e.message);
    }

    // Map, and keep the first record when two share a document id
        const byDocId = new Map();
        const duplicates = [];
        const invalid = [];
        for (const r of records) {
          const fields = mapSourceFields(r, company);
          const idOk =
            fields.id &&
            !fields.id.endsWith('_') &&
            !fields.id.includes('/') &&
            fields.id.length < 200;

          if (!idOk) {
            invalid.push(str(r.id));
          } else if (byDocId.has(fields.id)) {
            duplicates.push(str(r.id));
          } else {
            byDocId.set(fields.id, { fields, raw: r });
          }
        }

    const col = db.collection(CUSTOMERS_COLLECTION);
    const entries = [...byDocId.entries()];
    const savedIds = []; // source ids that were really written
    const errors = [];
    let created = 0;
    let updated = 0;

    const CHUNK = 400;
    for (let i = 0; i < entries.length; i += CHUNK) {
      const chunk = entries.slice(i, i + CHUNK);
      try {
        const snaps = await db.getAll(...chunk.map(([docId]) => col.doc(docId)));
        const batch = db.batch();
        let c = 0;
        let u = 0;

        chunk.forEach(([docId, { fields, raw }], idx) => {
          const exists = snaps[idx].exists;
          batch.set(
            col.doc(docId),
            exists ? fields : { ...newDocDefaults(raw), ...fields },
            { merge: true }
          );
          exists ? u++ : c++;
        });

        await batch.commit();
        created += c;
        updated += u;
        savedIds.push(...chunk.map(([, { fields }]) => fields.sourceid));
      } catch (e) {
        console.error(`Customer chunk ${i / CHUNK + 1} failed:`, e);
        errors.push(`chunk ${i / CHUNK + 1}: ${e.message}`);
      }
    }

    // Acknowledge only what was saved. A failure here is harmless on re-run (merge writes).
    let acknowledged = 0;
    let ackError = null;
    if (savedIds.length > 0) {
      try {
        const ack = await acknowledge(savedIds);
        acknowledged = ack.updated;
      } catch (e) {
        console.error('Customer acknowledgment failed:', e);
        ackError = e.message;
      }
    }

    console.log(
      `Customer sync: ${created} created, ${updated} updated, ${duplicates.length} duplicates, ` +
        `${acknowledged}/${savedIds.length} acknowledged, ${errors.length} errors.`
    );

    return {
      total: records.length,
      created,
      updated,
      saved: savedIds.length,
      acknowledged,
      duplicates: duplicates.length,
      errors,
      ackError,
    };
  }
);