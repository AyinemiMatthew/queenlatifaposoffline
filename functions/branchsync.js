const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

if (!getApps().length) initializeApp();
const db = getFirestore();

const BRANCHES_API_URL = 'https://queenlatifahenterprise.com/pos/firebase/branches';
const BRANCHES_COLLECTION = 'branches';

const str = (v) => (v ?? '').toString().trim();
const slug = (s) => str(s).toLowerCase().replace(/[^a-z0-9]/g, '');

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
  throw new Error(`Branches API failed: ${lastErr.message}`);
}

async function fetchAllBranches() {
  const first = await getJson(BRANCHES_API_URL);
  const all = Array.isArray(first.data) ? [...first.data] : [];
  const totalPages = Number(first.total_pages) || 1;

  for (let page = 2; page <= totalPages; page++) {
    const body = await getJson(`${BRANCHES_API_URL}?page=${page}`);
    if (!Array.isArray(body.data) || body.data.length === 0) break;
    all.push(...body.data);
  }
  return all;
}

function parseCreated(date, time) {
  const d = str(date);
  if (!d) return Timestamp.now();
  const t = str(time);
  const parsed = new Date(t ? `${d}T${t}Z` : `${d}T00:00:00Z`);
  return isNaN(parsed.getTime()) ? Timestamp.now() : Timestamp.fromDate(parsed);
}

/** warehouse "1" -> Warehouse; otherwise use the source branchtype, else Sales Branch. */
function resolveBranchType(r) {
  const isWarehouse = str(r.warehouse) === '1';
  if (isWarehouse) return 'Warehouse';
  return str(r.branchtype) || 'Sales Branch';
}

/** Fields the endpoint owns. Written on every sync. */
function mapSourceFields(r, company) {
  const branchname = str(r.name);
  return {
    id: `${company.companyid.toLowerCase()}${slug(branchname)}`,
    sourceid: str(r.id),
    branchname,
    branchcontact: str(r.contact),
    address: str(r.address) || str(r.location),
    location: str(r.location),
    branchtype: resolveBranchType(r),
    stockcheck: str(r.stockcheck) === '1',
    companyid: company.companyid,
    companyemail: company.companyemail,
    staff: str(r.staff),
    updatedat: FieldValue.serverTimestamp(),
    updatedby: 'branchsync',
  };
}

/** Only on first creation. */
const newDocDefaults = (r) => ({
  date: parseCreated(r.date, r.time),
  deletedat: null,
  deletedby: '',
});

exports.syncBranches = onCall(
  { region: 'us-central1', timeoutSeconds: 120 },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required.');

    // Company comes from the caller's staff record, not from the endpoint
    const email = str(req.auth.token.email).toLowerCase();
    const staffSnap = await db.collection('staff').doc(email).get();
    if (!staffSnap.exists) {
      throw new HttpsError('permission-denied', 'No staff record for this user.');
    }
    const staff = staffSnap.data();
    const company = { companyid: str(staff.companyid), companyemail: email };
    if (!company.companyid) {
      throw new HttpsError('failed-precondition', 'Staff record has no company.');
    }

    let records;
    try {
      records = await fetchAllBranches();
    } catch (e) {
      console.error(e);
      throw new HttpsError('unavailable', e.message);
    }

    const byDocId = new Map();
    const duplicates = [];
    const invalid = [];
    for (const r of records) {
      const fields = mapSourceFields(r, company);
      const idOk = fields.branchname && fields.id.length > company.companyid.length;
      if (!idOk) invalid.push(str(r.id));
      else if (byDocId.has(fields.id)) duplicates.push(str(r.id));
      else byDocId.set(fields.id, { fields, raw: r });
    }

    const col = db.collection(BRANCHES_COLLECTION);
    const entries = [...byDocId.entries()];
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
      } catch (e) {
        console.error(`Branch chunk ${i / CHUNK + 1} failed:`, e);
        errors.push(`chunk ${i / CHUNK + 1}: ${e.message}`);
      }
    }

    console.log(
      `Branch sync: ${created} created, ${updated} updated, ` +
        `${duplicates.length} duplicates, ${invalid.length} invalid, ${errors.length} errors.`
    );

    return {
      total: records.length,
      created,
      updated,
      duplicates: duplicates.length,
      invalid: invalid.length,
      errors,
    };
  }
);