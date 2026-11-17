
const admin = require("firebase-admin");

const {
  initializeApp,
  getApps,
} = require("firebase-admin/app");

const {
  getFirestore,
  FieldValue,
  FieldPath,
  Timestamp,
} = require("firebase-admin/firestore");

const {
  getAuth,
} = require("firebase-admin/auth");

// Initialize Firebase once
if (getApps().length === 0) {
  initializeApp();
}

// Get Firestore instance
const db = getFirestore();

// Get Authentication instance
const auth = getAuth();

// Firestore compatibility
const firestoreCompat = function () {
  return db;
};

firestoreCompat.FieldValue = FieldValue;
firestoreCompat.FieldPath = FieldPath;
firestoreCompat.Timestamp = Timestamp;

// Attach Firestore compatibility
admin.firestore = firestoreCompat;

// Attach Authentication compatibility
admin.auth = function () {
  return auth;
};

module.exports = {
  admin,
  db,
  auth,
  FieldValue,
  FieldPath,
  Timestamp,
};
