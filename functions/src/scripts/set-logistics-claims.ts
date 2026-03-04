/**
 * One-time script to set { logistics: true } custom claim on a Firebase user.
 *
 * This allows the compre-aqui-entregas admin panel (which uses Firebase client SDK)
 * to read orders, drivers, and vehicles collections via Firestore security rules.
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/scripts/set-logistics-claims.ts <USER_UID>
 *
 * After running, the user must logout and login again for the claim to take effect.
 */

import * as admin from "firebase-admin";

// Use Application Default Credentials via gcloud or GOOGLE_APPLICATION_CREDENTIALS
admin.initializeApp({
  projectId: "marketplace-e5ef1",
  credential: admin.credential.applicationDefault(),
});

async function main() {
  const uid = process.argv[2];

  if (!uid) {
    console.error("Usage: npx ts-node src/scripts/set-logistics-claims.ts <USER_UID>");
    process.exit(1);
  }

  try {
    // Verify user exists
    const user = await admin.auth().getUser(uid);
    console.log(`Found user: ${user.email || user.uid}`);

    // Get existing claims to preserve them
    const existingClaims = user.customClaims || {};

    // Set logistics claim (merge with existing)
    await admin.auth().setCustomUserClaims(uid, {
      ...existingClaims,
      logistics: true,
    });

    // Verify
    const updatedUser = await admin.auth().getUser(uid);
    console.log("Custom claims set successfully:", updatedUser.customClaims);
    console.log("\nIMPORTANT: The user must logout and login again for the claim to take effect.");
  } catch (error) {
    console.error("Error setting custom claims:", error);
    process.exit(1);
  }
}

main();
