import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { v4 as uuidv4 } from "uuid";
import { config } from "../config";

/**
 * Number of days after payment before auto-confirming delivery.
 * If the buyer doesn't confirm or dispute within this period,
 * the system auto-confirms and starts the release countdown.
 */
const AUTO_CONFIRM_DAYS = 7;

/**
 * Scheduled function that handles payment lifecycle:
 *
 * 1. Auto-confirms delivery for old orders where the buyer didn't act
 * 2. Releases payments that have been confirmed and held long enough
 *
 * Payment is only released AFTER the buyer confirms delivery (or auto-confirm).
 * This protects buyers by giving them a window to report problems.
 *
 * Flow:
 *   Payment approved → held (waiting for delivery)
 *   Buyer confirms (or auto-confirm after 7 days) → deliveryConfirmedAt set
 *   deliveryConfirmedAt + PAYMENT_HOLD_HOURS → released
 */
export async function releaseHeldPayments(): Promise<void> {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();

  functions.logger.info("Starting payment lifecycle check");

  try {
    // ================================================================
    // Step 1: Auto-confirm old orders where buyer hasn't acted
    // ================================================================
    const autoConfirmCutoff = new Date(Date.now() - AUTO_CONFIRM_DAYS * 24 * 60 * 60 * 1000);
    const autoConfirmTimestamp = admin.firestore.Timestamp.fromDate(autoConfirmCutoff);

    // Find paid+held orders older than AUTO_CONFIRM_DAYS with no delivery confirmation
    const unconfirmedSnap = await db
      .collection("orders")
      .where("paymentStatus", "==", "paid")
      .where("paymentSplit.status", "==", "held")
      .where("paidAt", "<=", autoConfirmTimestamp)
      .get();

    let autoConfirmed = 0;
    for (const orderDoc of unconfirmedSnap.docs) {
      const orderData = orderDoc.data();

      // Skip if already confirmed or already released
      if (orderData.deliveryConfirmedAt || orderData.paymentReleasedAt) continue;

      // Only auto-confirm orders that have actually been shipped/delivered
      if (!["shipped", "delivered", "out_for_delivery"].includes(orderData.status)) {
        functions.logger.info(`Skipping auto-confirm for order ${orderDoc.id} with status ${orderData.status}`);
        continue;
      }

      try {
        await orderDoc.ref.update({
          deliveryConfirmedAt: now,
          status: orderData.status === "shipped" || orderData.status === "ready" ? "delivered" : orderData.status,
          statusHistory: admin.firestore.FieldValue.arrayUnion({
            status: "delivered",
            timestamp: now,
            note: `Entrega confirmada automaticamente após ${AUTO_CONFIRM_DAYS} dias sem resposta do comprador`,
          }),
          updatedAt: now,
        });

        autoConfirmed++;

        // Notify buyer that delivery was auto-confirmed
        const buyerNotifId = uuidv4();
        await db.collection("notifications").doc(buyerNotifId).set({
          id: buyerNotifId,
          userId: orderData.buyerUserId,
          title: "Entrega confirmada automaticamente",
          body: `Pedido #${orderData.orderNumber || orderDoc.id.substring(0, 8)} foi confirmado automaticamente. Se houve algum problema, entre em contato com o suporte.`,
          type: "auto_delivery_confirmed",
          data: { orderId: orderDoc.id },
          isRead: false,
          createdAt: now,
        });

        functions.logger.info("Auto-confirmed delivery", { orderId: orderDoc.id });
      } catch (err) {
        functions.logger.error("Error auto-confirming order", { orderId: orderDoc.id, error: err });
      }
    }

    if (autoConfirmed > 0) {
      functions.logger.info(`Auto-confirmed ${autoConfirmed} deliveries`);
    }

    // ================================================================
    // Step 2: Release payments for confirmed deliveries past hold period
    // ================================================================
    const holdHours = config.platform.paymentHoldHours;
    const releaseCutoff = new Date(Date.now() - holdHours * 60 * 60 * 1000);
    const releaseCutoffTimestamp = admin.firestore.Timestamp.fromDate(releaseCutoff);

    // Find orders that have delivery confirmation AND the hold period has expired
    const confirmedSnap = await db
      .collection("orders")
      .where("paymentStatus", "==", "paid")
      .where("paymentSplit.status", "==", "held")
      .where("deliveryConfirmedAt", "<=", releaseCutoffTimestamp)
      .get();

    if (confirmedSnap.empty && autoConfirmed === 0) {
      functions.logger.info("No payments to release");
      return;
    }

    let released = 0;
    let errors = 0;

    for (const orderDoc of confirmedSnap.docs) {
      try {
        const orderData = orderDoc.data();
        const orderId = orderDoc.id;
        const tenantId = orderData.tenantId;
        const sellerAmount = orderData.paymentSplit?.sellerAmount || 0;

        if (!tenantId || sellerAmount <= 0) {
          functions.logger.warn("Invalid order data for release", { orderId });
          continue;
        }

        // Already released? Skip
        if (orderData.paymentReleasedAt) continue;

        // Must have delivery confirmation to release
        if (!orderData.deliveryConfirmedAt) continue;

        // Query transaction record BEFORE the Firestore transaction
        const txSnap = await db
          .collection("transactions")
          .where("orderId", "==", orderId)
          .where("type", "==", "sale")
          .limit(1)
          .get();

        const txRef = txSnap.empty ? null : txSnap.docs[0].ref;

        await db.runTransaction(async (transaction) => {
          const freshOrder = await transaction.get(orderDoc.ref);
          if (!freshOrder.exists || freshOrder.data()?.paymentReleasedAt) {
            return;
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

          // 3. Update transaction record
          if (txRef) {
            transaction.update(txRef, {
              status: "completed",
              updatedAt: now,
            });
          }
        });

        // 4. Notify seller - resolve actual Firebase Auth UID from tenant
        const orderNumber = orderData.orderNumber || orderId.substring(0, 8);
        const tenantDoc = await db.collection("tenants").doc(tenantId).get();
        const sellerUserId = tenantDoc.data()?.ownerId;

        if (sellerUserId) {
          const notifId = uuidv4();
          await db.collection("notifications").doc(notifId).set({
            id: notifId,
            userId: sellerUserId,
            title: "Pagamento liberado!",
            body: `R$ ${sellerAmount.toFixed(2)} do pedido #${orderNumber} foi creditado na sua conta do Mercado Pago.`,
            type: "payment_released",
            data: { orderId },
            isRead: false,
            createdAt: now,
          });
        }

        // Send FCM
        try {
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
                    body: `R$ ${sellerAmount.toFixed(2)} do pedido #${orderNumber} já está disponível.`,
                  },
                  data: { type: "payment_released", orderId },
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

    functions.logger.info("Payment lifecycle check completed", {
      autoConfirmed,
      released,
      errors,
    });
  } catch (error) {
    functions.logger.error("Error in releaseHeldPayments", error);
    throw error;
  }
}
