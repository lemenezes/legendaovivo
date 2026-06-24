require('dotenv').config();
let admin;

try {
  // This dependency is optional for deployments that do not use Firebase Admin.
  admin = require('firebase-admin');

  if (
    process.env.FIREBASE_NODE_SERVICE_ACCOUNT_KEY &&
    (!admin.apps || admin.apps.length === 0)
  ) {
    admin.initializeApp({
      credential: admin.credential.cert(
        JSON.parse(process.env.FIREBASE_NODE_SERVICE_ACCOUNT_KEY)
      ),
    });
  }
} catch (e) {
  admin = null;
}

module.exports = () => admin;
