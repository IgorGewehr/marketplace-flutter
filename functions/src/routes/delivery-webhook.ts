import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { config } from "../config";

const router = Router();

const VALID_STATUSES = ["collected", "in_transit", "delivered"] as const;
type DeliveryWebhookStatus = typeof VALID_STATUSES[number];

/**
 * POST /api/delivery-webhook
 * Inbound webhook from the driver/delivery app.
 * Authenticated via x-delivery-api-key header (not Firebase Auth).
 */
router.post("/", async (req: Request, res: Response): Promise<void> => {
  // Authenticate via API key
  const apiKey = req.headers["x-delivery-api-key"] as string | undefined;
  const expectedKey = config.delivery.webhookApiKey;

  if (!expectedKey) {
    functions.logger.error("DELIVERY_WEBHOOK_API_KEY not configured — rejecting request");
    res.status(503).json({ error: "Webhook not configured" });
    return;
  }

  if (!apiKey || apiKey !== expectedKey) {
    res.status(401).json({ error: "Invalid API key" });
    return;
  }

  const { orderId, status, driverName, driverPhone, notes } = req.body;

  if (!orderId || !status) {
    res.status(400).json({ error: "orderId and status are required" });
    return;
  }

  if (!VALID_STATUSES.includes(status as DeliveryWebhookStatus)) {
    res.status(400).json({
      error: `Invalid status '${status}'. Valid: ${VALID_STATUSES.join(", ")}`,
    });
    return;
  }

  const db = admin.firestore();

  try {
    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      res.status(404).json({ error: "Order not found" });
      return;
    }

    const data = orderDoc.data()!;
    const now = admin.firestore.Timestamp.now();

    const updateData: Record<string, unknown> = {
      updatedAt: now,
    };

    const historyEntry: Record<string, unknown> = {
      timestamp: now,
      note: notes || null,
      source: "delivery_webhook",
    };

    switch (status as DeliveryWebhookStatus) {
    case "collected":
      updateData.deliveryStatus = "collected";
      updateData.status = "shipped";
      updateData.collectedAt = now;
      if (driverName) updateData.driverName = driverName;
      if (driverPhone) updateData.driverPhone = driverPhone;
      historyEntry.status = "shipped";
      historyEntry.note = notes || `Coletado pelo entregador${driverName ? ` ${driverName}` : ""}`;
      break;

    case "in_transit":
      updateData.deliveryStatus = "in_transit";
      historyEntry.status = "in_transit";
      historyEntry.note = notes || "Pedido em trânsito";
      break;

    case "delivered":
      updateData.deliveryStatus = "delivered";
      updateData.status = "delivered";
      historyEntry.status = "delivered";
      historyEntry.note = notes || "Pedido entregue pelo entregador";
      break;
    }

    updateData.statusHistory = admin.firestore.FieldValue.arrayUnion(historyEntry);

    await orderRef.update(updateData);

    functions.logger.info("Delivery webhook processed", {
      orderId,
      status,
      driverName: driverName || null,
    });

    // Send notifications (fire-and-forget)
    sendDeliveryNotifications(db, data, orderId, status as DeliveryWebhookStatus, driverName).catch((err) => {
      functions.logger.error("Failed to send delivery notifications", { orderId, error: String(err) });
    });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error processing delivery webhook", { orderId, error });
    res.status(500).json({ error: "Internal server error" });
  }
});

async function sendDeliveryNotifications(
  db: admin.firestore.Firestore,
  orderData: admin.firestore.DocumentData,
  orderId: string,
  status: DeliveryWebhookStatus,
  driverName?: string,
): Promise<void> {
  const orderNumber = (orderData.orderNumber as string) || orderId.substring(0, 8);
  const now = admin.firestore.Timestamp.now();

  const statusMessages: Record<DeliveryWebhookStatus, { title: string; body: string }> = {
    collected: {
      title: "Pedido coletado!",
      body: `Seu pedido ${orderNumber} foi coletado${driverName ? ` por ${driverName}` : ""} e está a caminho.`,
    },
    in_transit: {
      title: "Pedido a caminho!",
      body: `Seu pedido ${orderNumber} está em trânsito para o endereço de entrega.`,
    },
    delivered: {
      title: "Pedido entregue!",
      body: `Seu pedido ${orderNumber} foi entregue. Confirme o recebimento no app.`,
    },
  };

  const msg = statusMessages[status];

  // Notify buyer
  const buyerUserId = orderData.buyerUserId as string;
  if (buyerUserId) {
    const notifId = uuidv4();
    await db.collection("notifications").doc(notifId).set({
      id: notifId,
      userId: buyerUserId,
      title: msg.title,
      body: msg.body,
      type: "delivery_status",
      data: { orderId, deliveryStatus: status },
      isRead: false,
      createdAt: now,
    });

    // FCM push to buyer
    try {
      const buyerDoc = await db.collection("users").doc(buyerUserId).get();
      const fcmTokens = buyerDoc.data()?.fcmTokens;
      if (Array.isArray(fcmTokens)) {
        for (const token of fcmTokens) {
          try {
            await admin.messaging().send({
              token,
              notification: { title: msg.title, body: msg.body },
              data: { type: "delivery_status", orderId, deliveryStatus: status },
              android: { priority: "high" },
              apns: { payload: { aps: { sound: "default" } } },
            });
          } catch { /* token may be invalid */ }
        }
      }
    } catch { /* best effort */ }
  }

  // Notify seller
  const tenantId = orderData.tenantId as string;
  if (tenantId) {
    try {
      const tenantDoc = await db.collection("tenants").doc(tenantId).get();
      const sellerUserId = tenantDoc.data()?.ownerId || tenantDoc.data()?.ownerUserId;
      if (sellerUserId) {
        const sellerMsg = {
          collected: { title: "Pedido coletado", body: `Pedido ${orderNumber} foi coletado pelo entregador.` },
          in_transit: { title: "Pedido em trânsito", body: `Pedido ${orderNumber} está em trânsito.` },
          delivered: { title: "Pedido entregue", body: `Pedido ${orderNumber} foi entregue ao comprador.` },
        };

        const notifId = uuidv4();
        await db.collection("notifications").doc(notifId).set({
          id: notifId,
          userId: sellerUserId,
          title: sellerMsg[status].title,
          body: sellerMsg[status].body,
          type: "delivery_status",
          data: { orderId, deliveryStatus: status },
          isRead: false,
          createdAt: now,
        });

        // FCM push to seller
        const sellerUserDoc = await db.collection("users").doc(sellerUserId).get();
        const sellerTokens = sellerUserDoc.data()?.fcmTokens;
        if (Array.isArray(sellerTokens)) {
          for (const token of sellerTokens) {
            try {
              await admin.messaging().send({
                token,
                notification: { title: sellerMsg[status].title, body: sellerMsg[status].body },
                data: { type: "delivery_status", orderId, deliveryStatus: status },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
              });
            } catch { /* token may be invalid */ }
          }
        }
      }
    } catch { /* best effort */ }
  }
}

export default router;
