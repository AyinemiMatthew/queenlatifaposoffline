const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

if (!getApps().length) initializeApp();
const db = getFirestore();

const WEBHOOK_URL =  'https://queenlatifahenterprise.com/pos/firebase/salesprocess';
const SALES_COLLECTION = 'sales';
const CALLBACK_COLLECTION = 'callback';

function serialize(value) {
  if (value === null || value === undefined) return null;

  // Firestore Timestamp (has toDate) -> ISO string
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

async function saveCallback(docId, code, message, raw) {
  try {
    await db.collection(CALLBACK_COLLECTION).doc(docId).set({
      docid: docId,
      responsecode: code,
      message: message,
      response: raw,
      syncstatus: 0,
      online: 0,
      createdAt: FieldValue.serverTimestamp(),

      });
  } catch (e) {
    console.error(`Could not save callback for ${docId}:`, e);
  }
}
exports.syncSaleToWebhook = onDocumentCreated(
  {
    document: `${SALES_COLLECTION}/{docId}`,
    timeoutSeconds: 60,
    retry: false,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const docId = event.params.docId;
    const data = snap.data();

    const online = Number(data.online) === 1 ? 1 : 0;

    const payload = {
      ...serialize(data),
      id: docId,
      syncstatus: 0,
      online,
    };

    let code = 0;
    let message = '';
    let raw = '';

    try {
      const res = await fetch(WEBHOOK_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(30000),
      });

      raw = (await res.text()).slice(0, 2000);

      let parsed = null;
      try { parsed = JSON.parse(raw); } catch (_) { /* body isn't JSON */ }

      // Prefer a code inside the response body, otherwise use the HTTP status
      code = Number(
        parsed?.code ?? parsed?.responseCode ?? parsed?.response_code ?? res.status
      );
      message = String(parsed?.message ?? res.statusText ?? raw.slice(0, 200));
    } catch (e) {
      // Network error, DNS failure, timeout
      code = 0;
      message = `Request failed: ${e.message}`;
    }

    if (code === 200) {
      await snap.ref.update({ syncstatus: 1, online: 1 });
      console.log(`Sale ${docId} synced.`);
    } else {
      await saveCallback(docId, code, message, raw);
      console.error(`Sale ${docId} sync failed (${code}): ${message}`);
    }
  }
);