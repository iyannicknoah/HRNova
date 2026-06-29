const { initializeApp, cert } = require('firebase-admin/app');
const { getSecurityRules } = require('firebase-admin/security-rules');
const path = require('path');

const serviceAccountPath = './serviceAccount.json';
const resolvedPath = path.resolve(__dirname, serviceAccountPath);

initializeApp({
  credential: cert(require(resolvedPath)),
});

const rulesContent = `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /companies/{companyId} {
      allow read, write: if request.auth != null && (
        request.auth.token.role == 'super_admin' || 
        request.auth.token.companyId == companyId
      );
      
      match /{document=**} {
        allow read, write: if request.auth != null && (
          request.auth.token.role == 'super_admin' || 
          request.auth.token.companyId == companyId
        );
      }
    }
  }
}`;

async function run() {
  try {
    console.log('Creating ruleset...');
    const rules = getSecurityRules();
    const rulesFile = {
      name: 'firestore.rules',
      content: rulesContent,
    };
    const ruleset = await rules.createRuleset(rulesFile);
    console.log('Ruleset created successfully:', ruleset.name);

    console.log("Releasing ruleset for database 'default'...");
    // releaseFirestoreRuleset takes the ruleset and the databaseId
    await rules.releaseFirestoreRuleset(ruleset, 'default');
    console.log("Successfully deployed security rules to database 'default'!");
  } catch (err) {
    console.error('Failed to deploy rules:', err);
  }
}

run();
