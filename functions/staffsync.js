const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

if (!getApps().length) initializeApp(); // safe if index.js already initialised
const db = getFirestore();

const STAFF_API_URL = 'https://queenlatifahenterprise.com/pos/firebase/staff';
const STAFF_COLLECTION = 'staff';
const META_DOC = 'system/staffsync';
const COOLDOWN_MS = 60 * 1000;


const COMPANY_OVERRIDES = {};

// Unknown levels leave `position` unset.
const LEVEL_TO_POSITION = { 'super admin': 0, admin: 1, 'sales attendance': 2 };
// Endpoint level -> level stored in Firestore
const LEVEL_ALIASES = { sales: 'sales attendance' };

const normalizeLevel = (v) => {
  const l = str(v).toLowerCase();
  return LEVEL_ALIASES[l] || l;
};
const str = (v) => (v ?? '').toString().trim();
const slug = (s) => str(s).toLowerCase().replace(/[^a-z0-9]/g, '');

function parsePricing(text) {
  const t = str(text).toLowerCase();
  return ['retail', 'wholesale', 'subsidy'].filter((p) => t.includes(p));
}

/** Endpoint record -> fields the endpoint owns (written on every sync). */
function mapSourceFields(r) {
  const email = str(r.email).toLowerCase();
  const override = COMPANY_OVERRIDES[str(r.companyid)] || {};
  const companyid = 'KS001';
  const company = override.company || str(r.company);
  const branchname = str(r.branchname || r.branch);
    const level = normalizeLevel(r.level);

  const out = {
    id: email,
    email,
    sourceid: str(r.id),
    staffid: str(r.staffid),
    name: str(r.name),
    phone: str(r.contact),
    department: str(r.department),
    company,
    companyid,
    branchname,
    branchid: branchname ? `${companyid.toLowerCase()}${slug(branchname)}` : '',
    accesslevel: level,
    pricingmode: parsePricing(r.pricing),
    lastSyncedAt: FieldValue.serverTimestamp(),
  };
  if (level in LEVEL_TO_POSITION) out.position = LEVEL_TO_POSITION[level];
  return out;
}

/** Fields only set when the doc is first created, so app settings are never overwritten. */
const NEW_DOC_DEFAULTS = () => ({
  allowDiscount: false,
  allowDiscountCode: false,
  allowedPaymentMethods: ['cash'],
  canEditPrice: false,
  canPrint: true,
  canSelectDate: false,
  canSellAnyBranch: false,
  salesWarehouseIds: [],
  salesWarehouseNames: [],
  warehouseids: [],
  warehousenames: [],
  isLoggedIn: false,
  imageurl: '',
  createdat: FieldValue.serverTimestamp(),
  createdby: 'staffsync',
});

async function fetchStaff() {
  let lastErr;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(STAFF_API_URL, {
        headers: { Accept: 'application/json' },
        signal: AbortSignal.timeout(30000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const body = await res.json();
      if (body.success === false) throw new Error(body.message || 'API reported failure');
      if (!Array.isArray(body.data)) throw new Error('No data array in response');
      return body.data;
    } catch (e) {
      lastErr = e;
      if (attempt < 3) await new Promise((r) => setTimeout(r, attempt * 1500));
    }
  }
  throw new Error(`Staff API failed after 3 attempts: ${lastErr.message}`);
}

exports.syncStaffOnLogin = onCall(
  { region: 'us-central1', timeoutSeconds: 120 },
  async (req) => {
    const loginEmail = str(req.data?.email).toLowerCase();

    // Cooldown: skip if synced recently AND this user already has a doc
    const metaRef = db.doc(META_DOC);
    const meta = await metaRef.get();
    const last = meta.exists ? meta.data().lastSyncMs || 0 : 0;
    if (Date.now() - last < COOLDOWN_MS) {
      const known = loginEmail
        ? (await db.collection(STAFF_COLLECTION).doc(loginEmail).get()).exists
        : true;
      if (known) return { skipped: true, reason: 'recently synced' };
    }

    let records;
    try {
      records = await fetchStaff();
    } catch (e) {
      console.error(e);
      throw new HttpsError('unavailable', e.message);
    }

    // Skip records with no usable email
    const mapped = [];
    let skipped = 0;
    for (const r of records) {
      const fields = mapSourceFields(r);
      if (!fields.email || !fields.email.includes('@')) {
        skipped++;
        continue;
      }
      mapped.push(fields);
    }

    const col = db.collection(STAFF_COLLECTION);
    let created = 0;
    let updated = 0;
    const CHUNK = 400;

    for (let i = 0; i < mapped.length; i += CHUNK) {
      const chunk = mapped.slice(i, i + CHUNK);
      const snaps = await db.getAll(...chunk.map((f) => col.doc(f.email)));
      const batch = db.batch();

      chunk.forEach((fields, idx) => {
        const exists = snaps[idx].exists;
        batch.set(
          col.doc(fields.email),
          exists ? fields : { ...NEW_DOC_DEFAULTS(), ...fields },
          { merge: true }
        );
        exists ? updated++ : created++;
      });

      await batch.commit();
    }

    await metaRef.set(
      { lastSyncMs: Date.now(), lastSyncAt: FieldValue.serverTimestamp(), created, updated, skipped },
      { merge: true }
    );

    console.log(`Staff sync: ${created} created, ${updated} updated, ${skipped} skipped.`);
    return { skipped: false, total: records.length, created, updated, skippedRecords: skipped };
  }
);