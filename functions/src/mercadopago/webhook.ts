import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Request, Response } from "express";
import { config } from "../config";
import { getPayment, validateWebhookSignature } from "./client";
import { getValidSellerToken } from "./oauth";
import { restoreOrderStock } from "./payments";
import { v4 as uuidv4 } from "uuid";

/**
 * Handle Mercado Pago webhook notifications.
 *
 * MP sends notifications for payment events:
 * - payment.created
 * - payment.updated
 *
 * Flow:
 * 1. Validate webhook signature (HMAC-SHA256)
 * 2. Fetch payment details from MP API
 * 3. Find associated order in Firestore
 * 4. Update order payment status
 * 5. If approved: generate delivery QR code, notify users
 * 6. If rejected/cancelled: update order accordingly
 */
export async function handleWebhook(req: Request, res: Response): Promise<void> {
  // Only accept POST
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method Not Allowed" });
    return;
  }

  // Enforce webhook secret before processing any payload.
  // Never allow payment events through without a configured secret.
  const webhookSecret = config.mercadoPago.webhookSecret;
  if (!webhookSecret) {
    functions.logger.error(
      "CRITICAL: MP_WEBHOOK_SECRET not configured. Rejecting webhook."
    );
    res.status(500).json({ error: "Webhook secret not configured" });
    return;
  }

  const { type, data, action } = req.body;
  const dataId = data?.id?.toString() || req.query["data.id"]?.toString() || "";

  functions.logger.info("Webhook received", { type, action, dataId });

  // Validate HMAC-SHA256 signature against the configured secret
  const xSignature = req.headers["x-signature"] as string || "";
  const xRequestId = req.headers["x-request-id"] as string || "";

  const isValid = validateWebhookSignature(
    xSignature,
    xRequestId,
    dataId,
    webhookSecret
  );

  if (!isValid) {
    functions.logger.error("Invalid webhook signature", { xSignature, xRequestId, dataId });
    res.status(400).json({ error: "Invalid signature" });
    return;
  }

  // Deduplication: skip webhooks we have already processed
  const db = admin.firestore();
  const dedupRef = xRequestId ? db.collection("webhook_processed").doc(xRequestId) : null;
  if (dedupRef) {
    const dedupDoc = await dedupRef.get();
    if (dedupDoc.exists) {
      functions.logger.info("Webhook already processed, skipping", { xRequestId });
      res.status(200).json({ received: true });
      return;
    }
  }

  // Process webhook then respond
  try {
    if (type === "payment") {
      await processPaymentNotification(dataId);
    } else if (type === "mp-connect") {
      await processSellerConnectionChange(dataId, action);
    } else if (type === "topic_chargebacks_wh" || type === "chargeback") {
      await processChargebackNotification(dataId);
    } else if (type === "topic_claims_integration_wh" || type === "claim") {
      functions.logger.warn("Claim/dispute notification received", { dataId, action });
      // Claims require manual review - log for now
    } else {
      functions.logger.info(`Unhandled webhook type: ${type}`, { dataId, action });
    }

    // Mark as processed AFTER successful processing to allow retries on failure
    if (dedupRef) {
      await dedupRef.set({
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        type: req.body?.type || "unknown",
      });
    }

    res.status(200).send("OK");
  } catch (error) {
    functions.logger.error("Error processing webhook", error);
    // Still respond 200 to avoid infinite retries, but log the error
    res.status(200).send("OK");
  }
}

/**
 * Process a payment notification from Mercado Pago.
 */
async function processPaymentNotification(paymentId: string): Promise<void> {
  if (!paymentId) {
    functions.logger.error("No payment ID in webhook");
    return;
  }

  const db = admin.firestore();

  // Marketplace payments are created with seller tokens, so find the order first
  // to get the tenant ID, then use the seller token to fetch payment details.
  let payment;

  // Search for order by payment gateway ID to get tenant context
  const orderByGatewaySnap = await db
    .collection("orders")
    .where("paymentGatewayId", "==", paymentId)
    .limit(1)
    .get();

  if (!orderByGatewaySnap.empty) {
    const tenantId = orderByGatewaySnap.docs[0].data().tenantId;
    try {
      const sellerToken = await getValidSellerToken(tenantId);
      payment = await getPayment(paymentId, sellerToken);
    } catch {
      // Seller token failed but order is ours - use platform token as emergency fallback
      functions.logger.info("Seller token failed, trying platform token", { paymentId, tenantId });
      try {
        payment = await getPayment(paymentId, config.mercadoPago.accessToken);
      } catch {
        functions.logger.error("Failed to fetch payment with both seller and platform tokens", { paymentId });
        return;
      }
    }
  } else {
    // No order found for this payment ID.
    // This can happen if the webhook arrives before order creation completes (race condition),
    // or if the payment belongs to a different platform. Do not use platform token as fallback.
    functions.logger.warn("No order found for paymentId - skipping. Possible race condition or unrelated payment.", { paymentId });
    return;
  }

  functions.logger.info("Payment details fetched", {
    paymentId: payment.id,
    status: payment.status,
    statusDetail: payment.status_detail,
    externalReference: payment.external_reference,
  });

  // Find the order by external_reference (order ID) or metadata
  const orderId = payment.external_reference ||
    (payment.metadata as Record<string, unknown>)?.order_id as string;

  if (!orderId) {
    functions.logger.error("No order ID found in payment", { paymentId: payment.id });
    return;
  }

  const orderRef = db.collection("orders").doc(orderId);
  const now = admin.firestore.Timestamp.now();

  // Map MP status to our payment status
  const paymentStatusMap: Record<string, string> = {
    approved: "paid",
    pending: "pending",
    authorized: "pending",
    in_process: "pending",
    in_mediation: "pending",
    rejected: "failed",
    cancelled: "failed",
    refunded: "refunded",
    charged_back: "refunded",
  };

  const newPaymentStatus = paymentStatusMap[payment.status] || "pending";

  // Don't downgrade status (e.g., don't go from 'paid' back to 'pending')
  const statusPriority: Record<string, number> = {
    pending: 0,
    paid: 1,
    failed: 2,
    refunded: 3,
  };

  // Use a Firestore transaction to atomically check order status + update order + update wallet.
  // This prevents duplicate wallet increments if two identical webhooks arrive simultaneously.
  let orderData: admin.firestore.DocumentData | undefined;
  let notificationEvent: "approved" | "failed" | "refunded" | null = null;

  try {
    await db.runTransaction(async (transaction) => {
      const orderSnap = await transaction.get(orderRef);

      if (!orderSnap.exists) {
        throw new Error("ORDER_NOT_FOUND");
      }

      orderData = orderSnap.data()!;
      const currentPaymentStatus = orderData.paymentStatus;

      if ((statusPriority[newPaymentStatus] ?? 0) <= (statusPriority[currentPaymentStatus] ?? 0)) {
        if (newPaymentStatus === currentPaymentStatus) {
          functions.logger.info("Payment status unchanged", { orderId, status: newPaymentStatus });
          throw new Error("STATUS_UNCHANGED");
        }
        // Allow refunded status to override paid
        if (newPaymentStatus !== "refunded" && currentPaymentStatus === "paid") {
          functions.logger.info("Skipping status downgrade", {
            orderId,
            current: currentPaymentStatus,
            new: newPaymentStatus,
          });
          throw new Error("STATUS_DOWNGRADE");
        }
      }

      // Build update object
      const updateData: Record<string, unknown> = {
        paymentStatus: newPaymentStatus,
        paymentGatewayId: payment.id.toString(),
        "paymentSplit.mpPaymentId": payment.id.toString(),
        updatedAt: now,
      };

      // If payment is approved, handle additional logic
      if (newPaymentStatus === "paid" && currentPaymentStatus !== "paid") {
        updateData.status = "confirmed";
        updateData.paidAt = now;
        updateData["paymentSplit.status"] = "held";

        updateData.statusHistory = admin.firestore.FieldValue.arrayUnion({
          status: "confirmed",
          timestamp: now,
          note: "Pagamento aprovado via Mercado Pago",
        });

        // Update seller wallet atomically within the same transaction
        const tenantId = orderData.tenantId;
        if (tenantId) {
          // Use the stored payment split values from order creation (not current config)
          const sellerAmount = orderData.paymentSplit?.sellerAmount || 0;

          const walletRef = db.collection("wallets").doc(tenantId);
          const walletSnap = await transaction.get(walletRef);
          if (walletSnap.exists) {
            const walletData = walletSnap.data()!;
            transaction.update(walletRef, {
              "balance.pending": (walletData.balance?.pending || 0) + sellerAmount,
              "balance.total": (walletData.balance?.total || 0) + sellerAmount,
              updatedAt: now,
            });
          } else {
            transaction.set(walletRef, {
              id: tenantId,
              tenantId: tenantId,
              status: "active",
              balance: {
                available: 0,
                pending: sellerAmount,
                blocked: 0,
                total: sellerAmount,
              },
              gatewayProvider: "mercadopago",
              createdAt: now,
              updatedAt: now,
            });
          }
        }

        notificationEvent = "approved";
      }

      // If payment failed
      if (newPaymentStatus === "failed") {
        updateData["paymentSplit.status"] = "failed";

        updateData.statusHistory = admin.firestore.FieldValue.arrayUnion({
          status: "payment_failed",
          timestamp: now,
          note: `Pagamento recusado: ${payment.status_detail}`,
        });

        notificationEvent = "failed";
      }

      // If refunded
      if (newPaymentStatus === "refunded") {
        updateData.status = "refunded";
        updateData["paymentSplit.status"] = "refunded";

        updateData.statusHistory = admin.firestore.FieldValue.arrayUnion({
          status: "refunded",
          timestamp: now,
          note: "Pagamento estornado",
        });

        // Reverse wallet balance atomically within the same transaction
        const tenantId = orderData.tenantId;
        if (tenantId && orderData.paymentSplit?.sellerAmount) {
          const reverseAmount = orderData.paymentSplit.sellerAmount;
          const walletRef = db.collection("wallets").doc(tenantId);
          const walletSnap = await transaction.get(walletRef);

          if (walletSnap.exists) {
            const walletData = walletSnap.data()!;
            const balance = walletData.balance || {};
            const wasPending = orderData.paymentSplit?.status === "held";

            if (wasPending) {
              transaction.update(walletRef, {
                "balance.pending": Math.max(0, (balance.pending || 0) - reverseAmount),
                "balance.total": Math.max(0, (balance.total || 0) - reverseAmount),
                updatedAt: now,
              });
            } else {
              transaction.update(walletRef, {
                "balance.available": Math.max(0, (balance.available || 0) - reverseAmount),
                "balance.total": Math.max(0, (balance.total || 0) - reverseAmount),
                updatedAt: now,
              });
            }
          }
        }

        notificationEvent = "refunded";
      }

      // Apply the order update atomically
      transaction.update(orderRef, updateData);
    });
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    if (
      errorMessage === "ORDER_NOT_FOUND" ||
      errorMessage === "STATUS_UNCHANGED" ||
      errorMessage === "STATUS_DOWNGRADE"
    ) {
      if (errorMessage === "ORDER_NOT_FOUND") {
        functions.logger.error("Order not found", { orderId });
      }
      return; // Already logged inside the transaction
    }
    throw error;
  }

  // Restore stock for refunded orders (root + variant quantities)
  if (notificationEvent === "refunded" && orderData && Array.isArray(orderData.items) && orderData.items.length > 0) {
    try {
      await restoreOrderStock(db, orderData.items as Record<string, unknown>[]);
      functions.logger.info("Stock restored for refunded order (webhook)", { orderId });
    } catch (stockErr) {
      functions.logger.error("Failed to restore stock for refunded order (webhook)", { orderId, error: stockErr });
      // Non-blocking — log for manual review
    }
  }

  // Post-transaction side effects (QR code, transaction record, notifications)
  // These run outside the transaction because they are idempotent side effects
  if (notificationEvent === "approved" && orderData) {
    // Generate delivery QR code
    const qrCodeId = uuidv4();
    const qrCodeData = {
      id: qrCodeId,
      orderId: orderId,
      code: `DEL-${orderId.substring(0, 8)}-${qrCodeId.substring(0, 6)}`.toUpperCase(),
      type: "delivery_confirmation",
      isUsed: false,
      createdAt: now,
      expiresAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days expiry
      ),
    };

    await db.collection("qr_codes").doc(qrCodeId).set(qrCodeData);
    await orderRef.update({ qrCodeId });

    functions.logger.info("Delivery QR code generated", { orderId, qrCodeId });

    // Create transaction record
    const tenantId = orderData.tenantId;
    if (tenantId) {
      const total = orderData.total || 0;
      const platformFee = orderData.paymentSplit?.platformFeeAmount || 0;
      const sellerAmount = orderData.paymentSplit?.sellerAmount || 0;

      const txId = uuidv4();
      await db.collection("transactions").doc(txId).set({
        id: txId,
        tenantId: tenantId,
        type: "sale",
        source: "marketplace",
        amount: total,
        fee: platformFee,
        netAmount: sellerAmount,
        description: `Venda - Pedido #${orderData.orderNumber || orderId.substring(0, 8)}`,
        status: "pending", // Will become 'completed' when released
        orderId: orderId,
        walletId: tenantId,
        gatewayTransactionId: payment.id.toString(),
        gatewayProvider: "mercadopago",
        metadata: {
          paymentMethod: payment.payment_method_id,
          feeBreakdown: {
            marketplace: platformFee,
            gateway: 0, // MP charges are separate
          },
        },
        createdAt: now,
        updatedAt: now,
      });

      functions.logger.info("Wallet updated and transaction created", {
        tenantId,
        sellerAmount,
        platformFee,
      });
    }
  }

  // Send notifications outside the transaction (fire-and-forget side effects)
  if (notificationEvent && orderData) {
    await sendPaymentNotifications(db, orderData, orderId, notificationEvent);
  }

  functions.logger.info("Order updated", { orderId, newPaymentStatus });
}

/**
 * Process seller MP connection/disconnection events.
 * Fired when a seller links or unlinks their MP account via OAuth.
 */
async function processSellerConnectionChange(userId: string, action: string): Promise<void> {
  if (!userId) return;

  const db = admin.firestore();

  // Find tenant by MP user ID
  const tenantsSnap = await db
    .collection("tenants")
    .where("mpConnection.mpUserId", "==", parseInt(userId))
    .limit(1)
    .get();

  if (tenantsSnap.empty) {
    functions.logger.warn("mp-connect: No tenant found for MP user", { userId, action });
    return;
  }

  const tenantDoc = tenantsSnap.docs[0];
  const tenantId = tenantDoc.id;

  if (action === "mp-connect.disconnected" || action === "application.deauthorized") {
    // Seller revoked access - mark as disconnected
    await tenantDoc.ref.update({
      "mpConnection.isConnected": false,
      "mpConnection.disconnectedAt": admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    // Clean up stored tokens
    const privateRef = tenantDoc.ref.collection("private").doc("mp_oauth");
    await privateRef.delete();

    functions.logger.warn("Seller disconnected from MP via webhook", { tenantId, userId, action });

    // Notify seller
    const tenantData = tenantDoc.data();
    const ownerId = tenantData?.ownerId || tenantData?.ownerUserId;
    if (ownerId) {
      const notifId = uuidv4();
      await db.collection("notifications").doc(notifId).set({
        id: notifId,
        userId: ownerId,
        title: "Mercado Pago desconectado",
        body: "Sua conta do Mercado Pago foi desconectada. Reconecte para continuar recebendo pagamentos.",
        type: "mp_disconnected",
        data: {},
        isRead: false,
        createdAt: admin.firestore.Timestamp.now(),
      });
    }
  } else {
    functions.logger.info("mp-connect event received", { tenantId, userId, action });
  }
}

/**
 * Process chargeback notifications.
 * A chargeback means the buyer disputed the payment with their bank/card issuer.
 */
async function processChargebackNotification(paymentId: string): Promise<void> {
  if (!paymentId) return;

  const db = admin.firestore();

  // Find order by payment ID
  const orderSnap = await db
    .collection("orders")
    .where("paymentGatewayId", "==", paymentId)
    .limit(1)
    .get();

  if (orderSnap.empty) {
    functions.logger.warn("Chargeback: No order found for payment", { paymentId });
    return;
  }

  const orderDoc = orderSnap.docs[0];
  const orderData = orderDoc.data();
  const orderId = orderDoc.id;
  const now = admin.firestore.Timestamp.now();

  // Atomically update order AND reverse wallet balance in a single transaction
  const tenantId = orderData.tenantId;
  await db.runTransaction(async (transaction) => {
    // Mark order as refunded due to chargeback
    transaction.update(orderDoc.ref, {
      paymentStatus: "refunded",
      status: "refunded",
      "paymentSplit.status": "chargedback",
      statusHistory: admin.firestore.FieldValue.arrayUnion({
        status: "refunded",
        timestamp: now,
        note: "Chargeback recebido - pagamento contestado pelo comprador",
      }),
      updatedAt: now,
    });

    // Reverse wallet balance within the same transaction
    if (tenantId && orderData.paymentSplit?.sellerAmount) {
      const reverseAmount = orderData.paymentSplit.sellerAmount;
      const walletRef = db.collection("wallets").doc(tenantId);
      const walletSnap = await transaction.get(walletRef);

      if (walletSnap.exists) {
        const walletData = walletSnap.data()!;
        const balance = walletData.balance || {};
        const splitStatus = orderData.paymentSplit?.status;

        if (splitStatus === "held") {
          transaction.update(walletRef, {
            "balance.pending": Math.max(0, (balance.pending || 0) - reverseAmount),
            "balance.total": Math.max(0, (balance.total || 0) - reverseAmount),
            updatedAt: now,
          });
        } else if (splitStatus === "released") {
          transaction.update(walletRef, {
            "balance.available": Math.max(0, (balance.available || 0) - reverseAmount),
            "balance.total": Math.max(0, (balance.total || 0) - reverseAmount),
            updatedAt: now,
          });
        }
      }
    }
  });

  // Restore stock for chargebacked orders (root + variant quantities)
  if (Array.isArray(orderData.items) && orderData.items.length > 0) {
    try {
      await restoreOrderStock(db, orderData.items as Record<string, unknown>[]);
      functions.logger.info("Stock restored for chargebacked order", { orderId });
    } catch (stockErr) {
      functions.logger.error("Failed to restore stock for chargebacked order", { orderId, error: stockErr });
      // Non-blocking — log for manual review
    }
  }

  functions.logger.warn("Chargeback processed", { orderId, paymentId, tenantId });

  // Notify seller and buyer
  const orderNumber = orderData.orderNumber || orderId.substring(0, 8);

  if (orderData.buyerUserId) {
    const notifId = uuidv4();
    await db.collection("notifications").doc(notifId).set({
      id: notifId,
      userId: orderData.buyerUserId,
      title: "Contestação de pagamento",
      body: `O pagamento do pedido #${orderNumber} foi contestado.`,
      type: "chargeback",
      data: { orderId },
      isRead: false,
      createdAt: now,
    });
  }

  if (tenantId) {
    const tenantDocSnap = await db.collection("tenants").doc(tenantId).get();
    const ownerId = tenantDocSnap.data()?.ownerId || tenantDocSnap.data()?.ownerUserId;
    if (ownerId) {
      const notifId = uuidv4();
      await db.collection("notifications").doc(notifId).set({
        id: notifId,
        userId: ownerId,
        title: "Chargeback recebido",
        body: `O pedido #${orderNumber} teve o pagamento contestado. Valor estornado.`,
        type: "chargeback",
        data: { orderId },
        isRead: false,
        createdAt: now,
      });
    }
  }
}

/**
 * Send push notifications about payment status changes.
 */
async function sendPaymentNotifications(
  db: admin.firestore.Firestore,
  orderData: Record<string, unknown>,
  orderId: string,
  event: "approved" | "failed" | "refunded"
): Promise<void> {
  const buyerUserId = orderData.buyerUserId as string;
  const tenantId = orderData.tenantId as string;
  const orderNumber = (orderData.orderNumber as string) || orderId.substring(0, 8);

  // Resolve seller's actual Firebase Auth UID from tenant
  let sellerUserId: string | null = null;
  if (tenantId) {
    try {
      const tenantDoc = await db.collection("tenants").doc(tenantId).get();
      sellerUserId = tenantDoc.data()?.ownerId || tenantDoc.data()?.ownerUserId || null;
    } catch {
      functions.logger.warn("Failed to resolve seller UID from tenant", { tenantId });
    }
  }

  const messages: { userId: string; title: string; body: string; type: string }[] = [];

  switch (event) {
    case "approved":
      messages.push({
        userId: buyerUserId,
        title: "Pagamento aprovado!",
        body: `Seu pedido #${orderNumber} foi confirmado.`,
        type: "payment_approved",
      });
      if (sellerUserId) {
        messages.push({
          userId: sellerUserId,
          title: "Nova venda!",
          body: `Pedido #${orderNumber} - Pagamento confirmado.`,
          type: "new_sale",
        });
      }
      break;
    case "failed":
      messages.push({
        userId: buyerUserId,
        title: "Pagamento recusado",
        body: `O pagamento do pedido #${orderNumber} foi recusado. Tente novamente.`,
        type: "payment_failed",
      });
      break;
    case "refunded":
      messages.push({
        userId: buyerUserId,
        title: "Pagamento estornado",
        body: `O pagamento do pedido #${orderNumber} foi estornado.`,
        type: "payment_refunded",
      });
      break;
  }

  const now = admin.firestore.Timestamp.now();

  for (const msg of messages) {
    // Store in-app notification
    const notifId = uuidv4();
    await db.collection("notifications").doc(notifId).set({
      id: notifId,
      userId: msg.userId,
      title: msg.title,
      body: msg.body,
      type: msg.type,
      data: { orderId },
      isRead: false,
      createdAt: now,
    });

    // Send push notification via FCM
    try {
      const userDoc = await db.collection("users").doc(msg.userId).get();
      const userData = userDoc.data();
      const fcmTokens = userData?.fcmTokens || (userData?.fcmToken ? [userData.fcmToken] : []);

      for (const token of fcmTokens) {
        try {
          await admin.messaging().send({
            token,
            notification: {
              title: msg.title,
              body: msg.body,
            },
            data: {
              type: msg.type,
              orderId: orderId,
            },
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: { sound: "default" },
              },
            },
          });
        } catch { /* token may be invalid */ }
      }
    } catch (error) {
      functions.logger.warn("Failed to send push notification", {
        userId: msg.userId,
        error,
      });
    }
  }
}
