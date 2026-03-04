/**
 * One-time migration script to set subscription plans on all existing tenants.
 *
 * Sets all tenants without a subscription to Pro plan with a 60-day promo period.
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/scripts/migrate-subscription-plans.ts
 */

import * as admin from "firebase-admin";

admin.initializeApp({
  projectId: "marketplace-e5ef1",
  credential: admin.credential.applicationDefault(),
});

const BATCH_LIMIT = 450;

async function main() {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const promoExpiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 60 * 24 * 60 * 60 * 1000)
  );

  const tenantsSnap = await db.collection("tenants").get();

  const tenantsWithoutSub = tenantsSnap.docs.filter((doc) => {
    const data = doc.data();
    return !data.subscription;
  });

  console.log(
    `Found ${tenantsSnap.size} tenants total, ${tenantsWithoutSub.length} without subscription`
  );

  if (tenantsWithoutSub.length === 0) {
    console.log("Nothing to migrate.");
    return;
  }

  let batchCount = 0;
  let batch = db.batch();
  let inBatch = 0;

  for (const doc of tenantsWithoutSub) {
    batch.update(doc.ref, {
      subscription: {
        plan: "pro",
        startedAt: now,
        updatedAt: now,
        updatedBy: "migration_script",
        promoExpiresAt,
      },
    });
    inBatch++;

    if (inBatch >= BATCH_LIMIT) {
      await batch.commit();
      batchCount++;
      console.log(`Committed batch ${batchCount} (${inBatch} docs)`);
      batch = db.batch();
      inBatch = 0;
    }
  }

  if (inBatch > 0) {
    await batch.commit();
    batchCount++;
    console.log(`Committed batch ${batchCount} (${inBatch} docs)`);
  }

  console.log(
    `Migration complete: ${tenantsWithoutSub.length} tenants updated to Pro plan.`
  );
}

main().catch((err) => {
  console.error("Migration failed:", err);
  process.exit(1);
});
