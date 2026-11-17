// functions/index.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');

const CALLBACK_URL =
  'https://queenlatifahenterprise.com/pos/firebase/itemreg_callback';

exports.ackItems = onCall(
  { region: 'us-central1', timeoutSeconds: 120 },
  async (req) => {
    if (!req.auth) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const ids = (req.data.ids || [])
      .map((id) => String(id).trim())
      .filter(Boolean);

    if (ids.length === 0) return { requested: 0, updated: 0 };

    let requested = 0;
    let updated = 0;

    // Chunk so one request never carries thousands of IDs
    for (let i = 0; i < ids.length; i += 100) {
      const chunk = ids.slice(i, i + 100);

      let res;
      try {
        res = await fetch(CALLBACK_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
          body: JSON.stringify({ ids: chunk }),
          signal: AbortSignal.timeout(30000),
        });
      } catch (e) {
        throw new HttpsError('unavailable', `Callback unreachable: ${e.message}`);
      }

      const text = await res.text();
      if (!res.ok) {
        throw new HttpsError('internal', `Callback HTTP ${res.status}: ${text.slice(0, 300)}`);
      }

      // The PHP prints notices/debug text before the JSON, so extract the JSON part
      const match = text.match(/\{[\s\S]*\}/);
      if (!match) {
        throw new HttpsError('internal', `No JSON in callback response: ${text.slice(0, 300)}`);
      }

      let parsed;
      try {
        parsed = JSON.parse(match[0]);
      } catch (e) {
        throw new HttpsError('internal', `Bad JSON from callback: ${text.slice(0, 300)}`);
      }

      if (parsed.success !== true) {
        throw new HttpsError('internal', `Callback failed: ${parsed.message || text.slice(0, 300)}`);
      }

      requested += Number(parsed.requested) || chunk.length;
      updated += Number(parsed.updated) || 0;
    }

    return { requested, updated };
  }
);