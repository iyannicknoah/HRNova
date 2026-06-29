const { initializeApp, cert, getApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const path = require('path');

const serviceAccountPath = './serviceAccount.json';
const resolvedPath = path.resolve(__dirname, serviceAccountPath);

initializeApp({
  credential: cert(require(resolvedPath)),
});

const db = getFirestore(getApp(), 'default');

async function run() {
  try {
    console.log("=== COMPANIES ===");
    const companiesSnap = await db.collection('companies').get();
    for (const doc of companiesSnap.docs) {
      console.log(`Company ID: ${doc.id}`);
      console.log(`Company Data:`, doc.data());
      
      // Also get settings
      const settingsSnap = await doc.ref.collection('settings').get();
      console.log(`Settings count: ${settingsSnap.size}`);
      for (const sDoc of settingsSnap.docs) {
        console.log(`  Settings Doc ID: ${sDoc.id}`);
        console.log(`  Settings Data:`, sDoc.data());
      }
      
      // Also get employees
      const employeesSnap = await doc.ref.collection('employees').get();
      console.log(`Employees count: ${employeesSnap.size}`);
      for (const eDoc of employeesSnap.docs) {
        console.log(`  Employee Doc ID: ${eDoc.id}`);
        console.log(`  Employee Data:`, eDoc.data());
      }
    }
  } catch (err) {
    console.error("Error reading DB:", err);
  }
}

run();
