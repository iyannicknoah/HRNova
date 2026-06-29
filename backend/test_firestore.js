const { initializeApp, cert, getApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const path = require('path');

const serviceAccountPath = './serviceAccount.json';
const resolvedPath = path.resolve(__dirname, serviceAccountPath);

initializeApp({
  credential: cert(require(resolvedPath)),
});

async function run() {
  const email = 'test-auth-' + Date.now() + '@example.com';
  const password = 'TestPassword123!';
  console.log(`Testing Auth createUser with email ${email}...`);
  try {
    const userRecord = await getAuth().createUser({
      email,
      password,
      displayName: 'Test User',
    });
    console.log('Auth user creation succeeded! UID:', userRecord.uid);
    
    // Now delete the user to clean up
    console.log('Cleaning up Auth user...');
    await getAuth().deleteUser(userRecord.uid);
    console.log('Auth user cleanup succeeded!');
  } catch (err) {
    console.error('Auth user creation/deletion failed:', err);
  }
}

run();
