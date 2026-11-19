const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

if (!getApps().length) initializeApp();
const db = getFirestore();

const cashier_url = 'https://queenlatifahenterprise.com/pos/firebase/cashier';
const SALES_COLLECTION = 'sales';
const CALLBACK_COLLECTION = 'callback';
const WATCHED_FIELDS = ['receiptby', 'printedby', 'receiptbyemail'];

const norm = (v) => (v ?? '').toString().trim();

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

/** Pulls the JSON out of a response that may have PHP notices around it. */
function extractJson(text) {
  const m = text.match(/\{[\s\S]*\}/);
  if (!m) return null;
  try { return JSON.parse(m[0]); } catch (_) { return null; }
}

async function saveCallback(docId, code, message, raw) {
  try {
    await db.collection(CALLBACK_COLLECTION).doc(`${docId}_update`).set({
      docid: docId,
      responsecode: code,
      message,
      response: raw,
      syncstatus: 0,
      source: 'receipt_update',
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    console.error(`Could not save callback for ${docId}:`, e);
  }
}

exports.syncSaleUpdateToEndpoint = onDocumentUpdated(
  {
    document: `${SALES_COLLECTION}/{docId}`,
    timeoutSeconds: 60,
    retry: false,
  },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    // Only continue if one of the watched fields actually changed
    const changed = WATCHED_FIELDS.filter((f) => norm(before[f]) !== norm(after[f]));
    if (changed.length === 0) return;

    const docId = event.params.docId;
    console.log(`Sale ${docId}: ${changed.join(', ')} changed, posting to endpoint.`);

    const payload = {
      ...serialize(after),
      id: docId,
      syncstatus: 0,
      online: Number(after.online) === 1 ? 1 : 0,
      event: 'receipt_update',
      changedFields: changed,
    };

    let code = 0;
    let message = '';
    let raw = '';

    try {
      const res = await fetch(cashier_url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(30000),
      });

      const text = await res.text();
      raw = text.slice(0, 2000);

      const parsed = extractJson(text);
      code = Number(
        parsed?.code ?? parsed?.responseCode ?? parsed?.response_code ?? res.status
      );
      message = String(parsed?.message ?? res.statusText ?? raw.slice(0, 200));
    } catch (e) {
      code = 0;
      message = `Request failed: ${e.message}`;
    }

    if (code === 200) {
      // Doesn't re-trigger the post: only the three watched fields start it
      await event.data.after.ref.update({ syncstatus: 1, online: 1 });
      await db.collection(CALLBACK_COLLECTION).doc(`${docId}_update`).delete().catch(() => {});
      console.log(`Sale ${docId} update synced.`);
    } else {
      await saveCallback(docId, code, message, raw);
      console.error(`Sale ${docId} update sync failed (${code}): ${message}`);
    }
  }
);