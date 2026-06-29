const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const path = require('path');

const serviceAccountPath = './serviceAccount.json';
const resolvedPath = path.resolve(__dirname, serviceAccountPath);

initializeApp({
  credential: cert(require(resolvedPath)),
});

async function run() {
  try {
    console.log("=== AUTH USERS ===");
    const listUsersResult = await getAuth().listUsers(100);
    for (const userRecord of listUsersResult.users) {
      console.log(`User: ${userRecord.uid} - ${userRecord.email} - Claims:`, userRecord.customClaims);
    }
  } catch (err) {
    console.error("Error listing users:", err);
  }
}

run();
