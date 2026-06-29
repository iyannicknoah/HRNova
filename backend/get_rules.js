const { initializeApp, cert } = require('firebase-admin/app');
const { getSecurityRules } = require('firebase-admin/security-rules');
const path = require('path');

const serviceAccountPath = './serviceAccount.json';
const resolvedPath = path.resolve(__dirname, serviceAccountPath);

initializeApp({
  credential: cert(require(resolvedPath)),
});

async function run() {
  try {
    console.log('Retrieving Firestore security rules...');
    const rules = await getSecurityRules().getFirestoreRuleset();
    console.log('Ruleset Name:', rules.name);
    console.log('Ruleset Source:');
    console.log(rules.source[0].content);
  } catch (err) {
    console.error('Failed to get security rules:', err);
  }
}

run();
