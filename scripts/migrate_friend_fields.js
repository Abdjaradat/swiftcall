/**
 * Migration script to add friend request fields to existing users
 * Run: node scripts/migrate_friend_fields.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateFriendFields() {
  try {
    const usersSnapshot = await db.collection('users').get();

    console.log(`Found ${usersSnapshot.size} users`);

    let updated = 0;
    let skipped = 0;

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of usersSnapshot.docs) {
      const data = doc.data();

      // Check if fields exist
      const needsUpdate = !data.hasOwnProperty('contacts') ||
                          !data.hasOwnProperty('incomingRequests') ||
                          !data.hasOwnProperty('outgoingRequests');

      if (needsUpdate) {
        batch.set(doc.ref, {
          contacts: data.contacts || [],
          incomingRequests: data.incomingRequests || [],
          outgoingRequests: data.outgoingRequests || [],
        }, { merge: true });

        updated++;
        batchCount++;

        // Firestore batch limit is 500
        if (batchCount >= 500) {
          await batch.commit();
          console.log(`Committed batch of ${batchCount} updates`);
          batchCount = 0;
        }
      } else {
        skipped++;
      }
    }

    // Commit remaining
    if (batchCount > 0) {
      await batch.commit();
      console.log(`Committed final batch of ${batchCount} updates`);
    }

    console.log(`\nMigration complete!`);
    console.log(`Updated: ${updated} users`);
    console.log(`Skipped: ${skipped} users (already had fields)`);

  } catch (error) {
    console.error('Migration error:', error);
    process.exit(1);
  }

  process.exit(0);
}

migrateFriendFields();
