import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";
import { config } from "../config";

const router = Router();

/**
 * POST /api/delivery/confirm
 * Confirm delivery using QR code.
 *
 * Called by the BUYER when they scan the delivery QR code.
 * This starts the 24h payment hold countdown.
 *
 * Body:
 *   { qrCode: string }  - The QR code value scanned
 *   OR
 *   { orderId: string }  - The order ID (manual confirmation)
 */
router.post("/confirm", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { qrCode, orderId: manualOrderId } = req.body;

  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    let orderId: string;

    if (qrCode) {
      // Find QR code document
      const qrSnap = await db
        .collection("qr_codes")
        .where("code", "==", qrCode)
        .where("isUsed", "==", false)
        .limit(1)
        .get();

      if (qrSnap.empty) {
        res.status(404).json({ error: "QR Code inválido ou já utilizado" });
        return;
      }

      const qrData = qrSnap.docs[0].data();

      // Check expiry
      if (qrData.expiresAt && qrData.expiresAt.toDate() < new Date()) {
        res.status(400).json({ error: "QR Code expirado" });
        return;
      }

      orderId = qrData.orderId;

      // Mark QR code as used
      await qrSnap.docs[0].ref.update({
        isUsed: true,
        usedAt: now,
        usedBy: uid,
      });
    } else if (manualOrderId) {
      orderId = manualOrderId;
    } else {
      res.status(400).json({ error: "QR Code ou ID do pedido obrigatório" });
      return;
    }

    // Get and validate order
    const orderRef = db.collection("orders").doc(orderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      res.status(404).json({ error: "Pedido não encontrado" });
      return;
    }

    const orderData = orderSnap.data()!;

    // Validate buyer owns this order
    if (orderData.buyerUserId !== uid) {
      res.status(403).json({ error: "Apenas o comprador pode confirmar a entrega" });
      return;
    }

    // Validate order status
    if (orderData.status !== "shipped" && orderData.status !== "delivered") {
      if (orderData.status === "ready") {
        // Allow confirmation for pickup orders
      } else {
        res.status(400).json({
          error: `Pedido não pode ser confirmado no status atual: ${orderData.status}`,
        });
        return;
      }
    }

    // Check if already confirmed
    if (orderData.deliveryConfirmedAt) {
      res.status(400).json({ error: "Entrega já confirmada" });
      return;
    }

    // Calculate payment release date
    const holdHours = config.platform.paymentHoldHours;
    const releaseDate = new Date(Date.now() + holdHours * 60 * 60 * 1000);

    // Update order
    await orderRef.update({
      status: "delivered",
      deliveryConfirmedAt: now,
      "paymentSplit.status": "held",
      "paymentSplit.heldUntil": admin.firestore.Timestamp.fromDate(releaseDate),
      statusHistory: admin.firestore.FieldValue.arrayUnion({
        status: "delivered",
        timestamp: now,
        note: "Entrega confirmada pelo comprador",
        userId: uid,
      }),
      updatedAt: now,
    });

    // Notify seller
    const tenantId = orderData.tenantId;
    const orderNumber = orderData.orderNumber || orderId.substring(0, 8);
    const sellerAmount = orderData.paymentSplit?.sellerAmount || 0;

    const notifId = uuidv4();
    await db.collection("notifications").doc(notifId).set({
      id: notifId,
      userId: tenantId,
      title: "Entrega confirmada!",
      body: `Pedido #${orderNumber} entregue. R$ ${sellerAmount.toFixed(2)} será liberado em ${holdHours}h.`,
      type: "delivery_confirmed",
      data: { orderId },
      isRead: false,
      createdAt: now,
    });

    // Send FCM
    try {
      const usersSnap = await db
        .collection("users")
        .where("tenantId", "==", tenantId)
        .limit(1)
        .get();

      if (!usersSnap.empty) {
        const fcmToken = usersSnap.docs[0].data().fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: "Entrega confirmada!",
              body: `Pedido #${orderNumber} entregue. Pagamento será liberado em ${holdHours}h.`,
            },
            data: { type: "delivery_confirmed", orderId },
          });
        }
      }
    } catch (pushError) {
      functions.logger.warn("Failed to send delivery push", pushError);
    }

    functions.logger.info("Delivery confirmed", {
      orderId,
      buyerId: uid,
      releaseDate: releaseDate.toISOString(),
    });

    res.json({
      success: true,
      deliveryConfirmedAt: now.toDate().toISOString(),
      paymentReleaseDate: releaseDate.toISOString(),
    });
  } catch (error) {
    functions.logger.error("Error confirming delivery", error);
    res.status(500).json({ error: "Erro ao confirmar entrega" });
  }
});

/**
 * GET /api/delivery/qr/:orderId
 * Get delivery QR code for an order.
 */
router.get("/qr/:orderId", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const orderId = String(req.params.orderId);

  try {
    const db = admin.firestore();
    const orderDoc = await db.collection("orders").doc(orderId).get();

    if (!orderDoc.exists) {
      res.status(404).json({ error: "Pedido não encontrado" });
      return;
    }

    const orderData = orderDoc.data()!;

    // Verify access (buyer or seller)
    if (orderData.buyerUserId !== uid) {
      const tenantId = await getTenantForUser(uid);
      if (orderData.tenantId !== tenantId) {
        res.status(403).json({ error: "Acesso negado" });
        return;
      }
    }

    if (!orderData.qrCodeId) {
      res.status(404).json({ error: "QR Code ainda não gerado para este pedido" });
      return;
    }

    const qrDoc = await db.collection("qr_codes").doc(orderData.qrCodeId).get();
    if (!qrDoc.exists) {
      res.status(404).json({ error: "QR Code não encontrado" });
      return;
    }

    const qrData = qrDoc.data()!;

    res.json({
      code: qrData.code,
      orderId: qrData.orderId,
      isUsed: qrData.isUsed || false,
      createdAt: qrData.createdAt?.toDate()?.toISOString(),
      expiresAt: qrData.expiresAt?.toDate()?.toISOString(),
    });
  } catch (error) {
    functions.logger.error("Error fetching QR code", error);
    res.status(500).json({ error: "Erro ao buscar QR Code" });
  }
});

export default router;
