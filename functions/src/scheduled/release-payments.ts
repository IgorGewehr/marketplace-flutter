import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { v4 as uuidv4 } from "uuid";
import { config } from "../config";

/**
 * Scheduled function that releases held payments to sellers.
 *
 * Runs every hour. Finds orders where:
 * - paymentStatus is "paid"
 * - paymentSplit.status is "held"
 * - paidAt + PAYMENT_HOLD_HOURS < now (hold period expired)
 * - paymentReleasedAt is not set (not yet released)
 *
 * For each qualifying order:
 * 1. Updates paymentSplit.status to 'released'
 * 2. Sets paymentReleasedAt timestamp
 * 3. Moves balance from pending to available in wallet
 * 4. Updates the transaction record to 'completed'
 * 5. Sends notification to seller
 */
export async function releaseHeldPayments(): Promise<void> {
  const db = admin.firestore();
  const holdHours = config.platform.paymentHoldHours;
  const cutoffTime = new Date(Date.now() - holdHours * 60 * 60 * 1000);
  const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffTime);
  const now = admin.firestore.Timestamp.now();

  functions.logger.info("Starting payment release check", {
    holdHours,
    cutoffTime: cutoffTime.toISOString(),
  });

  try {
    // Query orders ready for payment release:
    // paid + held + paidAt older than hold period
    const ordersSnap = await db
      .collection("orders")
      .where("paymentStatus", "==", "paid")
      .where("paymentSplit.status", "==", "held")
      .where("paidAt", "<=", cutoffTimestamp)
      .get();

    if (ordersSnap.empty) {
      functions.logger.info("No payments to release");
      return;
    }

    functions.logger.info(`Found ${ordersSnap.size} payments to release`);

    let released = 0;
    let errors = 0;

    for (const orderDoc of ordersSnap.docs) {
      try {
        const orderData = orderDoc.data();
        const orderId = orderDoc.id;
        const tenantId = orderData.tenantId;
        const sellerAmount = orderData.paymentSplit?.sellerAmount || 0;

        if (!tenantId || sellerAmount <= 0) {
          functions.logger.warn("Invalid order data for release", { orderId });
          continue;
        }

        // Already released? Skip (double-check)
        if (orderData.paymentReleasedAt) {
          functions.logger.info("Payment already released, skipping", { orderId });
          continue;
        }

        // Query transaction record BEFORE the transaction (queries not allowed inside transactions)
        const txSnap = await db
          .collection("transactions")
          .where("orderId", "==", orderId)
          .where("type", "==", "sale")
          .limit(1)
          .get();

        const txRef = txSnap.empty ? null : txSnap.docs[0].ref;

        // Use a transaction for atomic updates
        await db.runTransaction(async (transaction) => {
          // Re-read order to prevent race conditions
          const freshOrder = await transaction.get(orderDoc.ref);
          if (!freshOrder.exists || freshOrder.data()?.paymentReleasedAt) {
            return; // Already processed
          }

          // 1. Update order
          transaction.update(orderDoc.ref, {
            paymentReleasedAt: now,
            "paymentSplit.status": "released",
            statusHistory: admin.firestore.FieldValue.arrayUnion({
              status: "payment_released",
              timestamp: now,
              note: `Pagamento de R$ ${sellerAmount.toFixed(2)} liberado para o vendedor`,
            }),
            updatedAt: now,
          });

          // 2. Update wallet - move from pending to available
          const walletRef = db.collection("wallets").doc(tenantId);
          const walletSnap = await transaction.get(walletRef);

          if (walletSnap.exists) {
            const walletData = walletSnap.data()!;
            const currentPending = walletData.balance?.pending || 0;
            const currentAvailable = walletData.balance?.available || 0;

            transaction.update(walletRef, {
              "balance.pending": Math.max(0, currentPending - sellerAmount),
              "balance.available": currentAvailable + sellerAmount,
              updatedAt: now,
            });
          }

          // 3. Update transaction record to 'completed'
          if (txRef) {
            transaction.update(txRef, {
              status: "completed",
              updatedAt: now,
            });
          }
        });

        // 4. Send notification to seller (outside transaction)
        const orderNumber = orderData.orderNumber || orderId.substring(0, 8);
        const notifId = uuidv4();
        await db.collection("notifications").doc(notifId).set({
          id: notifId,
          userId: tenantId,
          title: "Pagamento liberado!",
          body: `R$ ${sellerAmount.toFixed(2)} do pedido #${orderNumber} foi liberado para sua carteira.`,
          type: "payment_released",
          data: { orderId },
          isRead: false,
          createdAt: now,
        });

        // Send FCM push notification
        try {
          // Find seller's user to get FCM token
          const usersSnap = await db
            .collection("users")
            .where("tenantId", "==", tenantId)
            .limit(1)
            .get();

          if (!usersSnap.empty) {
            const sellerData = usersSnap.docs[0].data();
            const fcmTokens = sellerData.fcmTokens || (sellerData.fcmToken ? [sellerData.fcmToken] : []);
            for (const token of fcmTokens) {
              try {
                await admin.messaging().send({
                  token,
                  notification: {
                    title: "Pagamento liberado!",
                    body: `R$ ${sellerAmount.toFixed(2)} do pedido #${orderNumber} está disponível para saque.`,
                  },
                  data: {
                    type: "payment_released",
                    orderId,
                  },
                  android: { priority: "high" },
                  apns: { payload: { aps: { sound: "default" } } },
                });
              } catch { /* token may be invalid */ }
            }
          }
        } catch (pushError) {
          functions.logger.warn("Failed to send release push notification", pushError);
        }

        released++;
        functions.logger.info("Payment released", { orderId, tenantId, sellerAmount });
      } catch (orderError) {
        errors++;
        functions.logger.error("Error releasing payment for order", {
          orderId: orderDoc.id,
          error: orderError,
        });
      }
    }

    functions.logger.info("Payment release completed", { released, errors, total: ordersSnap.size });
  } catch (error) {
    functions.logger.error("Error in releaseHeldPayments", error);
    throw error;
  }
}
