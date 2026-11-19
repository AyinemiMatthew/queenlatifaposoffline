const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

if (!getApps().length) initializeApp();
const db = getFirestore();

const ENDPOINT = 'https://queenlatifahenterprise.com/pos/firebase/salesprocess';
const CALLBACK_COLLECTION = 'callback';
const WATCHED_FIELDS = ['receiptby', 'printedby', 'receiptbyemail'];

const norm = (v) => (v ?? '').toString().trim();
const isSalesPoint = (d) => norm(d.branchType).toLowerCase() === 'sales point';

function serialize(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'object' && typeof value.toDate === 'function') {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) return value.map(serialize);
  if (typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = serialize(v);
    return out;
  }
  return value;
}

function extractJson(text) {
  const m = text.match(/\{[\s\S]*\}/);
  if (!m) return null;
  try { return JSON.parse(m[0]); } catch (_) { return null; }
}

/** Posts one sale and records the outcome. Never throws. */
async function postSale(ref, docId, data, extra, callbackId) {
  const payload = {
    ...serialize(data),
    id: docId,
    syncstatus: 0,
    online: Number(data.online) === 1 ? 1 : 0,
    ...extra,
  };

  let code = 0;
  let message = '';
  let raw = '';

  try {
    const res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(30000),
    });
    const text = await res.text();
    raw = text.slice(0, 2000);
    const parsed = extractJson(text);
    code = Number(parsed?.code ?? parsed?.responseCode ?? parsed?.response_code ?? res.status);
    message = String(parsed?.message ?? res.statusText ?? raw.slice(0, 200));
  } catch (e) {
    message = `Request failed: ${e.message}`;
  }

  try {
    if (code === 200) {
      await ref.update({ syncstatus: 1, online: 1 });
      await db.collection(CALLBACK_COLLECTION).doc(callbackId).delete().catch(() => {});
      console.log(`Sale ${docId} posted (${extra.event}).`);
    } else {
      await db.collection(CALLBACK_COLLECTION).doc(callbackId).set({
        docid: docId,
        responsecode: code,
        message,
        response: raw,
        syncstatus: 0,
        source: extra.event,
        createdAt: FieldValue.serverTimestamp(),
      });
      console.error(`Sale ${docId} post failed (${code}): ${message}`);
    }
  } catch (e) {
    console.error(`Could not record result for ${docId}:`, e);
  }
}

// ON CREATE
exports.syncSaleOnCreate = onDocumentCreated(
  { document: 'sales/{docId}', timeoutSeconds: 60, retry: false },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const docId = event.params.docId;
    const data = snap.data();

    // Sales Point without a receipt: wait for the receiptby update
    if (isSalesPoint(data) && norm(data.receiptby) === '') {
      console.log(`Sale ${docId} is a Sales Point sale awaiting receipt; not posted yet.`);
      return;
    }

    await postSale(snap.ref, docId, data, { event: 'sale_created' }, docId);
  }
);

// ON UPDATE
exports.syncSaleOnUpdate = onDocumentUpdated(
  { document: 'sales/{docId}', timeoutSeconds: 60, retry: false },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const changed = WATCHED_FIELDS.filter((f) => norm(before[f]) !== norm(after[f]));
    if (changed.length === 0) return;

    const docId = event.params.docId;
    const ref = event.data.after.ref;

    // First post for a Sales Point sale: receiptby went from empty to filled
    const released =
      isSalesPoint(after) &&
      norm(before.receiptby) === '' &&
      norm(after.receiptby) !== '';
       //&& Number(after.syncstatus) !== 1;

    if (released) {
      await postSale(ref, docId, after, { event: 'sale_created', changedFields: changed }, docId);
      return;
    }

    // Sales Point sale still waiting for its receipt: printedby or receiptbyemail alone don't release it
    if (isSalesPoint(after) && norm(after.receiptby) === '' ) return;

    // Any other change to a watched field re-posts the sale
    await postSale(ref, docId, after, { event: 'receipt_update', changedFields: changed }, `${docId}_update`);
  }
);