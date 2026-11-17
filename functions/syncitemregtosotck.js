// functions/index.js
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const https = require('https');

exports.fetchStockPage = onCall({ region: 'us-central1' }, async (req) => {
  const page = Number(req.data.page) || 1;
  const limit = Number(req.data.limit) || 100;
  //const url = `https://kologsoft.site/queenlatifah/production/api/test?page=${page}&limit=${limit}`;
 const url = `https://queenlatifahenterprise.com/pos/firebase/item_reg?page=${page}&limit=${limit}`;

  // TEMPORARY: remove once the server certificate is renewed
  const agent = new https.Agent({ rejectUnauthorized: false });

  return new Promise((resolve, reject) => {
    https.get(url, { agent }, (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => {
        try { resolve(JSON.parse(body)); }
        catch (e) { reject(new HttpsError('internal', 'Invalid JSON from API')); }
      });
    }).on('error', (e) => reject(new HttpsError('unavailable', e.message)));
  });
});