import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Request, Response } from "express";
import { config } from "../config";
import { getPayment, validateWebhookSignature } from "./client";
import { getValidSellerToken } from "./oauth";
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
    res.status(405).send("Method Not Allowed");
    return;
  }

  const { type, data, action } = req.body;
  const dataId = data?.id?.toString() || req.query["data.id"]?.toString() || "";

  functions.logger.info("Webhook received", { type, action, dataId });

  // Validate webhook signature
  // In production, webhook secret MUST be configured
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

  if (!config.mercadoPago.webhookSecret && !isEmulator) {
    functions.logger.error(
      "CRITICAL: MP_WEBHOOK_SECRET is not configured. " +
      "Webhook validation is disabled, which is a security risk. " +
      "Set MP_WEBHOOK_SECRET via Firebase Secret Manager."
    );
    // In production, reject if no secret is configured
    res.status(500).send("Webhook secret not configured");
    return;
  }

  if (config.mercadoPago.webhookSecret) {
    const xSignature = req.headers["x-signature"] as string || "";
    const xRequestId = req.headers["x-request-id"] as string || "";

    const isValid = validateWebhookSignature(
      xSignature,
      xRequestId,
      dataId,
      config.mercadoPago.webhookSecret
    );

    if (!isValid) {
      functions.logger.error("Invalid webhook signature", { xSignature, xRequestId, dataId });
      res.status(401).send("Invalid signature");
      return;
    }
  }

  // Process webhook then respond
  try {
    if (type === "payment") {
      await processPaymentNotification(dataId);
    } else {
      functions.logger.info(`Unhandled webhook type: ${type}`);
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

  // Try to determine which access token to use for fetching payment details.
  // First try with platform token, if that fails, try seller tokens.
  let payment;
  try {
    payment = await getPayment(paymentId, config.mercadoPago.accessToken);
  } catch {
    // Platform token didn't work - payment may have been created with seller token.
    // Try to find the order first to get the tenant ID, then use seller token.
    functions.logger.info("Platform token failed for payment fetch, trying to find order for seller token");

    // Search for order by payment gateway ID
    const orderSnap = await db
      .collection("orders")
      .where("paymentGatewayId", "==", paymentId)
      .limit(1)
      .get();

    if (!orderSnap.empty) {
      const tenantId = orderSnap.docs[0].data().tenantId;
      try {
        const sellerToken = await getValidSellerToken(tenantId);
        payment = await getPayment(paymentId, sellerToken);
      } catch {
        functions.logger.error("Failed to fetch payment with both platform and seller tokens", { paymentId });
        return;
      }
    } else {
      functions.logger.error("Cannot fetch payment - no matching order found", { paymentId });
      return;
    }
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
  const orderSnap = await orderRef.get();

  if (!orderSnap.exists) {
    functions.logger.error("Order not found", { orderId });
    return;
  }

  const orderData = orderSnap.data()!;
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
  const currentPaymentStatus = orderData.paymentStatus;

  // Don't downgrade status (e.g., don't go from 'paid' back to 'pending')
  const statusPriority: Record<string, number> = {
    pending: 0,
    paid: 1,
    failed: 2,
    refunded: 3,
  };

  if ((statusPriority[newPaymentStatus] ?? 0) <= (statusPriority[currentPaymentStatus] ?? 0)) {
    if (newPaymentStatus === currentPaymentStatus) {
      functions.logger.info("Payment status unchanged", { orderId, status: newPaymentStatus });
      return;
    }
    // Allow refunded status to override paid
    if (newPaymentStatus !== "refunded" && currentPaymentStatus === "paid") {
      functions.logger.info("Skipping status downgrade", {
        orderId,
        current: currentPaymentStatus,
        new: newPaymentStatus,
      });
      return;
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
    // Update order status to confirmed
    updateData.status = "confirmed";

    // Record when payment was approved (used by release-payments scheduler)
    updateData.paidAt = now;

    // Set payment split to 'held' (payment is held for PAYMENT_HOLD_HOURS before release)
    updateData["paymentSplit.status"] = "held";

    // Add status history entry
    const statusHistoryEntry = {
      status: "confirmed",
      timestamp: now,
      note: "Pagamento aprovado via Mercado Pago",
    };

    updateData.statusHistory = admin.firestore.FieldValue.arrayUnion(statusHistoryEntry);

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
    updateData.qrCodeId = qrCodeId;

    functions.logger.info("Delivery QR code generated", { orderId, qrCodeId });

    // Update seller wallet - add to pending balance
    const tenantId = orderData.tenantId;
    if (tenantId) {
      const platformFeePercentage = config.platform.feePercentage;
      const total = orderData.total || 0;
      const platformFee = Math.round(total * (platformFeePercentage / 100) * 100) / 100;
      const sellerAmount = Math.round((total - platformFee) * 100) / 100;

      updateData["paymentSplit.platformFeeAmount"] = platformFee;
      updateData["paymentSplit.platformFeePercentage"] = platformFeePercentage;
      updateData["paymentSplit.sellerAmount"] = sellerAmount;

      // Update wallet pending balance
      const walletRef = db.collection("wallets").doc(tenantId);
      await db.runTransaction(async (transaction) => {
        const walletSnap = await transaction.get(walletRef);
        if (walletSnap.exists) {
          const walletData = walletSnap.data()!;
          transaction.update(walletRef, {
            "balance.pending": (walletData.balance?.pending || 0) + sellerAmount,
            "balance.total": (walletData.balance?.total || 0) + sellerAmount,
            updatedAt: now,
          });
        } else {
          // Create wallet if it doesn't exist
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
      });

      // Create transaction record
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

    // Send notifications
    await sendPaymentNotifications(db, orderData, orderId, "approved");
  }

  // If payment failed
  if (newPaymentStatus === "failed") {
    updateData["paymentSplit.status"] = "failed";

    const statusHistoryEntry = {
      status: "payment_failed",
      timestamp: now,
      note: `Pagamento recusado: ${payment.status_detail}`,
    };
    updateData.statusHistory = admin.firestore.FieldValue.arrayUnion(statusHistoryEntry);

    await sendPaymentNotifications(db, orderData, orderId, "failed");
  }

  // If refunded
  if (newPaymentStatus === "refunded") {
    updateData.status = "cancelled";
    updateData["paymentSplit.status"] = "refunded";

    const statusHistoryEntry = {
      status: "cancelled",
      timestamp: now,
      note: "Pagamento estornado",
    };
    updateData.statusHistory = admin.firestore.FieldValue.arrayUnion(statusHistoryEntry);

    // Reverse wallet balance if needed
    const tenantId = orderData.tenantId;
    if (tenantId && orderData.paymentSplit?.sellerAmount) {
      const reverseAmount = orderData.paymentSplit.sellerAmount;
      const walletRef = db.collection("wallets").doc(tenantId);

      await db.runTransaction(async (transaction) => {
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
      });
    }

    await sendPaymentNotifications(db, orderData, orderId, "refunded");
  }

  // Apply the update
  await orderRef.update(updateData);
  functions.logger.info("Order updated", { orderId, newPaymentStatus });
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

  const messages: { userId: string; title: string; body: string; type: string }[] = [];

  switch (event) {
    case "approved":
      messages.push({
        userId: buyerUserId,
        title: "Pagamento aprovado!",
        body: `Seu pedido #${orderNumber} foi confirmado.`,
        type: "payment_approved",
      });
      messages.push({
        userId: tenantId, // Will resolve to seller's user ID
        title: "Nova venda!",
        body: `Pedido #${orderNumber} - Pagamento confirmado.`,
        type: "new_sale",
      });
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
