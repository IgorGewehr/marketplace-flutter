import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { config } from "../config";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";
import { createPayment, getPayment, refundPayment, MpPaymentRequest } from "./client";
import { getValidSellerToken } from "./oauth";

const router = Router();

/**
 * POST /api/orders
 * Create a new order from the buyer's cart and process payment.
 *
 * Body:
 *   deliveryType: string
 *   deliveryAddress?: object
 *   paymentMethod: string (pix, creditCard, debitCard)
 *   cardTokenId?: string (for card payments)
 *   installments?: number
 *   customerNotes?: string
 */
router.post("/orders", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  const {
    deliveryType,
    deliveryAddress,
    paymentMethod,
    cardTokenId,
    installments = 1,
    customerNotes,
  } = req.body;

  const db = admin.firestore();
  let orderId = "";

  try {
    const now = admin.firestore.Timestamp.now();

    // Get user data
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      res.status(404).json({ error: "Usuário não encontrado" });
      return;
    }
    const userData = userDoc.data()!;

    // Get cart items
    const cartSnap = await db
      .collection("carts")
      .doc(uid)
      .collection("items")
      .get();

    if (cartSnap.empty) {
      res.status(400).json({ error: "Carrinho vazio" });
      return;
    }

    // Build order items and calculate totals
    const items: Record<string, unknown>[] = [];
    let subtotal = 0;
    let tenantId = "";

    for (const doc of cartSnap.docs) {
      const item = doc.data();
      const itemTotal = (item.unitPrice || 0) * (item.quantity || 1);
      subtotal += itemTotal;

      if (!tenantId) {
        tenantId = item.tenantId || "";
      } else if (item.tenantId && item.tenantId !== tenantId) {
        res.status(400).json({ error: "Todos os itens do carrinho devem ser do mesmo vendedor" });
        return;
      }

      items.push({
        productId: item.productId,
        variantId: item.variantId || null,
        name: item.productName || item.name,
        sku: item.sku || null,
        imageUrl: item.imageUrl || null,
        quantity: item.quantity || 1,
        unitPrice: item.unitPrice || 0,
        discount: item.discount || 0,
        total: itemTotal,
      });
    }

    if (!tenantId) {
      res.status(400).json({ error: "Vendedor não identificado nos itens do carrinho" });
      return;
    }

    // Calculate fees
    const deliveryFee = 0; // TODO: Calculate based on distance/type
    const discount = 0; // TODO: Apply coupon
    const total = subtotal - discount + deliveryFee;
    const platformFeePercentage = config.platform.feePercentage;
    const platformFeeAmount = Math.round(total * (platformFeePercentage / 100) * 100) / 100;
    const sellerAmount = Math.round((total - platformFeeAmount) * 100) / 100;

    // Generate order number
    const orderNumber = `RDB-${Date.now().toString(36).toUpperCase()}`;

    // Create order in Firestore
    orderId = uuidv4();
    const orderData: Record<string, unknown> = {
      id: orderId,
      tenantId,
      buyerUserId: uid,
      orderNumber,
      source: "marketplace",
      items,
      subtotal,
      discount,
      deliveryFee,
      total,
      deliveryType: deliveryType || "delivery",
      deliveryAddress: deliveryAddress || null,
      paymentMethod: paymentMethod,
      paymentStatus: "pending",
      status: "pending",
      statusHistory: [
        {
          status: "pending",
          timestamp: now,
          note: "Pedido criado",
        },
      ],
      customerNotes: customerNotes || null,
      paymentSplit: {
        platformFeeAmount,
        platformFeePercentage,
        sellerAmount,
        status: "pending",
      },
      createdAt: now,
      updatedAt: now,
    };

    // Process payment based on method
    const idempotencyKey = orderId;
    const buyerEmail = userData.email || `${uid}@marketplace.local`;
    const buyerName = userData.displayName || userData.name || "";
    const [firstName, ...lastNameParts] = buyerName.split(" ");
    const lastName = lastNameParts.join(" ") || firstName;

    // Idempotency check: prevent duplicate order creation
    const idempotencyRef = db.collection("idempotency_keys").doc(idempotencyKey);
    const idempotencyDoc = await idempotencyRef.get();

    if (idempotencyDoc.exists) {
      const existing = idempotencyDoc.data()!;
      if (existing.status === "completed") {
        // Already processed - return existing order
        const existingOrder = await db.collection("orders").doc(orderId).get();
        if (existingOrder.exists) {
          res.status(201).json(serializeOrder(existingOrder.data()!));
          return;
        }
      }
      if (existing.status === "processing") {
        res.status(409).json({ error: "Pedido já está sendo processado. Aguarde." });
        return;
      }
    }

    // Mark as processing
    await idempotencyRef.set({
      orderId,
      status: "processing",
      createdAt: admin.firestore.Timestamp.now(),
    });

    // Get seller's MP access token for marketplace split
    let sellerAccessToken: string;
    let useMarketplaceSplit = true;
    try {
      sellerAccessToken = await getValidSellerToken(tenantId);
    } catch {
      // Seller not connected to MP - block checkout
      await idempotencyRef.delete();
      res.status(403).json({
        error: "Este vendedor ainda não conectou o Mercado Pago. Não é possível finalizar a compra.",
        code: "SELLER_NOT_CONNECTED",
      });
      return;
    }

    // Build webhook URL
    const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
    const region = process.env.FUNCTION_REGION || "southamerica-east1";
    const webhookUrl = `https://${region}-${projectId}.cloudfunctions.net/mpWebhook`;

    // Validate total is positive
    if (total <= 0) {
      res.status(400).json({ error: "Valor do pedido inválido" });
      return;
    }

    if (paymentMethod === "pix") {
      // Create PIX payment
      const paymentReq: MpPaymentRequest = {
        transaction_amount: total,
        description: `Pedido ${orderNumber} - Rei do Brique`,
        payment_method_id: "pix",
        payer: {
          email: buyerEmail,
          first_name: firstName,
          last_name: lastName,
          identification: userData.document
            ? {
                type: userData.documentType || "CPF",
                number: userData.document.replace(/\D/g, ""),
              }
            : undefined,
        },
        notification_url: webhookUrl,
        external_reference: orderId,
        ...(useMarketplaceSplit ? { application_fee: platformFeeAmount } : {}),
        metadata: {
          order_id: orderId,
          order_number: orderNumber,
          tenant_id: tenantId,
          buyer_id: uid,
        },
      };

      const mpPayment = await createPayment(paymentReq, sellerAccessToken, idempotencyKey);

      // Extract PIX data
      const pixData = mpPayment.point_of_interaction?.transaction_data;
      orderData.pixCode = pixData?.qr_code || null;
      orderData.pixQrCodeUrl = pixData?.ticket_url || null;
      orderData.pixExpiration = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 15 * 60 * 1000) // 15 min expiry
      );
      orderData.paymentGatewayId = mpPayment.id.toString();
      orderData["paymentSplit"] = {
        ...(orderData.paymentSplit as Record<string, unknown>),
        mpPaymentId: mpPayment.id.toString(),
      };

      functions.logger.info("PIX payment created", {
        orderId,
        mpPaymentId: mpPayment.id,
        status: mpPayment.status,
      });
    } else if (paymentMethod === "creditCard" || paymentMethod === "debitCard") {
      // Create card payment
      if (!cardTokenId) {
        res.status(400).json({ error: "Token do cartão obrigatório" });
        return;
      }

      const paymentReq: MpPaymentRequest = {
        transaction_amount: total,
        description: `Pedido ${orderNumber} - Rei do Brique`,
        payment_method_id: paymentMethod === "debitCard" ? "debit_card" : "credit_card",
        token: cardTokenId,
        installments: paymentMethod === "creditCard" ? installments : 1,
        payer: {
          email: buyerEmail,
          first_name: firstName,
          last_name: lastName,
          identification: userData.document
            ? {
                type: userData.documentType || "CPF",
                number: userData.document.replace(/\D/g, ""),
              }
            : undefined,
        },
        notification_url: webhookUrl,
        external_reference: orderId,
        ...(useMarketplaceSplit ? { application_fee: platformFeeAmount } : {}),
        metadata: {
          order_id: orderId,
          order_number: orderNumber,
          tenant_id: tenantId,
          buyer_id: uid,
        },
      };

      const mpPayment = await createPayment(paymentReq, sellerAccessToken, idempotencyKey);

      orderData.paymentGatewayId = mpPayment.id.toString();
      orderData["paymentSplit"] = {
        ...(orderData.paymentSplit as Record<string, unknown>),
        mpPaymentId: mpPayment.id.toString(),
      };

      // If card payment is immediately approved
      if (mpPayment.status === "approved") {
        orderData.paymentStatus = "paid";
        orderData.paidAt = now;
        orderData.status = "confirmed";
        (orderData.paymentSplit as Record<string, unknown>).status = "held";
        (orderData.statusHistory as Record<string, unknown>[]).push({
          status: "confirmed",
          timestamp: now,
          note: "Pagamento aprovado via cartão",
        });
      }

      functions.logger.info("Card payment created", {
        orderId,
        mpPaymentId: mpPayment.id,
        status: mpPayment.status,
      });
    } else {
      res.status(400).json({ error: "Método de pagamento inválido" });
      return;
    }

    // Save order
    await db.collection("orders").doc(orderId).set(orderData);

    // Mark idempotency key as completed
    await idempotencyRef.update({
      status: "completed",
      mpPaymentId: orderData.paymentGatewayId || null,
      completedAt: admin.firestore.Timestamp.now(),
    });

    // Clear cart
    const batch = db.batch();
    for (const doc of cartSnap.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();

    // ---- Notify buyer and seller (fire-and-forget) ----
    const notifyUsers = async () => {
      try {
        const itemCount = items.length;
        const itemsLabel = itemCount === 1 ? "1 item" : `${itemCount} itens`;

        // Notify buyer: order created
        const buyerNotifId = uuidv4();
        await db.collection("notifications").doc(buyerNotifId).set({
          id: buyerNotifId,
          userId: uid,
          title: "Pedido realizado!",
          body: `Seu pedido ${orderNumber} com ${itemsLabel} foi criado. Aguardando pagamento.`,
          type: "order_created",
          data: { orderId },
          isRead: false,
          createdAt: now,
        });

        // Notify seller: new order received
        const tenantDoc = await db.collection("tenants").doc(tenantId).get();
        const tenantData = tenantDoc.data();
        const sellerUserId = tenantData?.ownerId;
        if (sellerUserId) {
          const sellerNotifId = uuidv4();
          await db.collection("notifications").doc(sellerNotifId).set({
            id: sellerNotifId,
            userId: sellerUserId,
            title: "Novo pedido recebido!",
            body: `Pedido ${orderNumber} - ${itemsLabel} - R$ ${total.toFixed(2)}`,
            type: "order_created",
            data: { orderId },
            isRead: false,
            createdAt: now,
          });

          // Send push to seller
          const sellerUserDoc = await db.collection("users").doc(sellerUserId).get();
          const sellerTokens = sellerUserDoc.data()?.fcmTokens;
          if (Array.isArray(sellerTokens) && sellerTokens.length > 0) {
            for (const token of sellerTokens) {
              try {
                await admin.messaging().send({
                  token,
                  notification: {
                    title: "Novo pedido recebido!",
                    body: `Pedido ${orderNumber} - ${itemsLabel} - R$ ${total.toFixed(2)}`,
                  },
                  data: { type: "order_created", orderId },
                  android: { priority: "high" },
                  apns: { payload: { aps: { sound: "default" } } },
                });
              } catch { /* token may be invalid */ }
            }
          }
        }

        // Send push to buyer
        const buyerTokens = userData.fcmTokens;
        if (Array.isArray(buyerTokens) && buyerTokens.length > 0) {
          for (const token of buyerTokens) {
            try {
              await admin.messaging().send({
                token,
                notification: {
                  title: "Pedido realizado!",
                  body: `Seu pedido ${orderNumber} com ${itemsLabel} foi criado.`,
                },
                data: { type: "order_created", orderId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
              });
            } catch { /* token may be invalid */ }
          }
        }
      } catch (notifError) {
        functions.logger.warn("Error sending order notifications", notifError);
      }
    };
    // Don't await - send notifications in background
    notifyUsers();

    // Convert Timestamps to ISO strings for JSON response
    const responseOrder = {
      ...orderData,
      pixExpiration: orderData.pixExpiration
        ? (orderData.pixExpiration as admin.firestore.Timestamp).toDate().toISOString()
        : null,
      createdAt: now.toDate().toISOString(),
      updatedAt: now.toDate().toISOString(),
      statusHistory: (orderData.statusHistory as Record<string, unknown>[]).map((sh) => ({
        ...sh,
        timestamp: now.toDate().toISOString(),
      })),
    };

    res.status(201).json(responseOrder);
  } catch (error) {
    // Mark idempotency key as failed so retries are allowed
    if (orderId) {
      try {
        await db.collection("idempotency_keys").doc(orderId).update({
          status: "failed",
          error: String(error),
          failedAt: admin.firestore.Timestamp.now(),
        });
      } catch { /* best effort cleanup */ }
    }

    functions.logger.error("Error creating order", error);
    res.status(500).json({ error: "Erro ao criar pedido" });
  }
});

/**
 * GET /api/orders
 * Get buyer's orders (paginated).
 */
router.get("/orders", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);
  const status = req.query.status ? String(req.query.status) : undefined;

  try {
    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("orders")
      .where("buyerUserId", "==", uid)
      .orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    // Get total count (approximation)
    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    // Paginate
    const offset = (page - 1) * limit;
    const ordersSnap = await query.offset(offset).limit(limit).get();

    const orders = ordersSnap.docs.map((doc) => {
      const data = doc.data();
      return serializeOrder(data);
    });

    res.json({
      orders,
      total,
      page,
      limit,
      hasMore: offset + limit < total,
    });
  } catch (error) {
    functions.logger.error("Error fetching orders", error);
    res.status(500).json({ error: "Erro ao buscar pedidos" });
  }
});

/**
 * GET /api/orders/:id
 * Get single order by ID.
 */
router.get("/orders/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const orderId = String(req.params.id);

  try {
    const db = admin.firestore();
    const orderDoc = await db.collection("orders").doc(orderId).get();

    if (!orderDoc.exists) {
      res.status(404).json({ error: "Pedido não encontrado" });
      return;
    }

    const data = orderDoc.data()!;

    // Verify access
    if (data.buyerUserId !== uid) {
      const tenantId = await getTenantForUser(uid);
      if (data.tenantId !== tenantId) {
        res.status(403).json({ error: "Acesso negado" });
        return;
      }
    }

    res.json(serializeOrder(data));
  } catch (error) {
    functions.logger.error("Error fetching order", error);
    res.status(500).json({ error: "Erro ao buscar pedido" });
  }
});

/**
 * GET /api/payments/:orderId/status
 * Check payment status for an order.
 */
router.get("/payments/:orderId/status", async (req: Request, res: Response): Promise<void> => {
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

    const data = orderDoc.data()!;

    // Verify access - buyer or seller only
    if (data.buyerUserId !== uid) {
      const tenantId = await getTenantForUser(uid);
      if (data.tenantId !== tenantId) {
        res.status(403).json({ error: "Acesso negado" });
        return;
      }
    }

    // If we have a payment gateway ID, fetch live status from MP
    if (data.paymentGatewayId) {
      try {
        const payment = await getPayment(
          data.paymentGatewayId,
          config.mercadoPago.accessToken
        );
        res.json({
          paymentStatus: mapMpStatus(payment.status),
          mpStatus: payment.status,
          mpStatusDetail: payment.status_detail,
        });
        return;
      } catch {
        // Fallback to stored status
      }
    }

    res.json({
      paymentStatus: data.paymentStatus,
    });
  } catch (error) {
    functions.logger.error("Error checking payment status", error);
    res.status(500).json({ error: "Erro ao verificar pagamento" });
  }
});

/**
 * POST /api/payments/:orderId/regenerate-pix
 * Regenerate a new PIX payment for an expired order.
 */
router.post("/payments/:orderId/regenerate-pix", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const orderId = String(req.params.orderId);

  try {
    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      res.status(404).json({ error: "Pedido não encontrado" });
      return;
    }

    const data = orderDoc.data()!;

    // Verify buyer ownership
    if (data.buyerUserId !== uid) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    // Only regenerate for pending PIX payments
    if (data.paymentMethod !== "pix" || data.paymentStatus === "paid") {
      res.status(400).json({ error: "Não é possível regenerar PIX para este pedido" });
      return;
    }

    const tenantId = data.tenantId;
    const total = data.total;
    const orderNumber = data.orderNumber;
    const platformFeeAmount = data.paymentSplit?.platformFeeAmount || 0;

    // Get user data for payer info
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() || {};
    const buyerEmail = userData.email || `${uid}@marketplace.local`;
    const buyerName = userData.displayName || userData.name || "";
    const [firstName, ...lastNameParts] = buyerName.split(" ");
    const lastName = lastNameParts.join(" ") || firstName;

    // Get seller's MP access token
    let sellerAccessToken: string;
    try {
      sellerAccessToken = await getValidSellerToken(tenantId);
    } catch {
      res.status(403).json({ error: "Vendedor não conectado ao Mercado Pago." });
      return;
    }

    // Build webhook URL
    const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
    const region = process.env.FUNCTION_REGION || "southamerica-east1";
    const webhookUrl = `https://${region}-${projectId}.cloudfunctions.net/mpWebhook`;

    const newIdempotencyKey = `${orderId}-pix-${Date.now()}`;

    const paymentReq: MpPaymentRequest = {
      transaction_amount: total,
      description: `Pedido ${orderNumber} - Rei do Brique`,
      payment_method_id: "pix",
      payer: {
        email: buyerEmail,
        first_name: firstName,
        last_name: lastName,
        identification: userData.document
          ? {
              type: userData.documentType || "CPF",
              number: userData.document.replace(/\D/g, ""),
            }
          : undefined,
      },
      notification_url: webhookUrl,
      external_reference: orderId,
      application_fee: platformFeeAmount,
      metadata: {
        order_id: orderId,
        order_number: orderNumber,
        tenant_id: tenantId,
        buyer_id: uid,
        regenerated: true,
      },
    };

    const mpPayment = await createPayment(paymentReq, sellerAccessToken, newIdempotencyKey);

    // Extract new PIX data
    const pixData = mpPayment.point_of_interaction?.transaction_data;
    const now = admin.firestore.Timestamp.now();

    await orderRef.update({
      pixCode: pixData?.qr_code || null,
      pixQrCodeUrl: pixData?.ticket_url || null,
      pixExpiration: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 15 * 60 * 1000)
      ),
      paymentGatewayId: mpPayment.id.toString(),
      "paymentSplit.mpPaymentId": mpPayment.id.toString(),
      updatedAt: now,
    });

    const updatedDoc = await orderRef.get();
    res.json(serializeOrder(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error regenerating PIX", error);
    res.status(500).json({ error: "Erro ao regenerar PIX" });
  }
});

/**
 * GET /api/seller/orders
 * Get seller's received orders.
 */
router.get("/seller/orders", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);
  const status = req.query.status ? String(req.query.status) : undefined;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("orders")
      .where("tenantId", "==", tenantId)
      .orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    const offset = (page - 1) * limit;
    const ordersSnap = await query.offset(offset).limit(limit).get();

    const orders = ordersSnap.docs.map((doc) => serializeOrder(doc.data()));

    res.json({
      orders,
      total,
      page,
      limit,
      hasMore: offset + limit < total,
    });
  } catch (error) {
    functions.logger.error("Error fetching seller orders", error);
    res.status(500).json({ error: "Erro ao buscar pedidos" });
  }
});

/**
 * PATCH /api/orders/:id/status
 * Update order status (seller only).
 */
router.patch("/orders/:id/status", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const orderId = String(req.params.id);
  const { status: newStatus, note } = req.body;

  const validTransitions: Record<string, string[]> = {
    pending: ["confirmed", "cancelled"],
    confirmed: ["preparing", "cancelled"],
    preparing: ["ready", "cancelled"],
    ready: ["shipped"],
    shipped: ["delivered"],
  };

  try {
    const tenantId = await getTenantForUser(uid);
    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      res.status(404).json({ error: "Pedido não encontrado" });
      return;
    }

    const data = orderDoc.data()!;

    // Verify seller ownership
    if (data.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    // Validate transition
    const allowedNext = validTransitions[data.status] || [];
    if (!allowedNext.includes(newStatus)) {
      res.status(400).json({
        error: `Não é possível alterar de '${data.status}' para '${newStatus}'`,
      });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const updateData: Record<string, unknown> = {
      status: newStatus,
      statusHistory: admin.firestore.FieldValue.arrayUnion({
        status: newStatus,
        timestamp: now,
        note: note || null,
        userId: uid,
      }),
      updatedAt: now,
    };

    // Handle cancellation with refund
    if (newStatus === "cancelled" && data.paymentStatus === "paid" && data.paymentGatewayId) {
      try {
        // Use seller's token if available (payment was created with seller token in marketplace split)
        let refundToken: string;
        try {
          refundToken = await getValidSellerToken(data.tenantId);
        } catch {
          refundToken = config.mercadoPago.accessToken;
        }

        await refundPayment(
          data.paymentGatewayId,
          refundToken,
          `refund-${orderId}`
        );
        updateData.paymentStatus = "refunded";
        functions.logger.info("Payment refunded for cancelled order", { orderId });
      } catch (refundError) {
        functions.logger.error("Failed to refund payment", refundError);
        // Still cancel the order but note the refund failure
        updateData.internalNotes = "Falha ao estornar pagamento - requer ação manual";
      }
    }

    await orderRef.update(updateData);

    const updatedDoc = await orderRef.get();
    res.json(serializeOrder(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error updating order status", error);
    res.status(500).json({ error: "Erro ao atualizar pedido" });
  }
});

/**
 * PATCH /api/seller/orders/:id/tracking
 * Add tracking code to an order (seller only).
 *
 * Body:
 *   trackingCode: string (required)
 *   shippingCompany?: string
 */
router.patch("/seller/orders/:id/tracking", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const orderId = String(req.params.id);
  const { trackingCode, shippingCompany } = req.body;

  if (!trackingCode || !trackingCode.trim()) {
    res.status(400).json({ error: "Codigo de rastreamento e obrigatorio" });
    return;
  }

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      res.status(404).json({ error: "Pedido nao encontrado" });
      return;
    }

    const data = orderDoc.data()!;

    // Verify seller ownership via tenantId
    if (data.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const updateData: Record<string, unknown> = {
      trackingCode: trackingCode.trim(),
      updatedAt: now,
    };

    if (shippingCompany) {
      updateData.shippingCompany = shippingCompany.trim();
    }

    await orderRef.update(updateData);

    const updatedDoc = await orderRef.get();
    res.json(serializeOrder(updatedDoc.data()!));

    functions.logger.info("Tracking code added to order", {
      orderId,
      trackingCode: trackingCode.trim(),
      shippingCompany: shippingCompany || null,
      tenantId,
    });
  } catch (error) {
    functions.logger.error("Error adding tracking code", error);
    res.status(500).json({ error: "Erro ao adicionar codigo de rastreamento" });
  }
});

/**
 * POST /api/payments/link
 * Generate a payment link (for sellers to share with buyers).
 *
 * Body:
 *   amount: number
 *   description: string
 */
router.post("/payments/link", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { amount, description } = req.body;

  if (!amount || amount <= 0) {
    res.status(400).json({ error: "Valor obrigatorio e deve ser positivo" });
    return;
  }

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    // Get seller's MP access token
    let sellerAccessToken: string;
    try {
      sellerAccessToken = await getValidSellerToken(tenantId);
    } catch {
      res.status(403).json({ error: "Conecte sua conta do Mercado Pago antes de gerar links de pagamento." });
      return;
    }

    // Create a preference (payment link) via MP API
    const response = await fetch("https://api.mercadopago.com/checkout/preferences", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${sellerAccessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        items: [
          {
            title: description || "Pagamento - Rei do Brique",
            quantity: 1,
            unit_price: parseFloat(amount),
            currency_id: "BRL",
          },
        ],
        payment_methods: {
          excluded_payment_types: [],
          installments: 12,
        },
        auto_return: "approved",
        external_reference: `link_${uid}_${Date.now()}`,
      }),
    });

    if (!response.ok) {
      const errorData = await response.text();
      functions.logger.error("MP preference creation failed", { status: response.status, body: errorData });
      res.status(500).json({ error: "Erro ao gerar link de pagamento" });
      return;
    }

    const data = await response.json();

    functions.logger.info("Payment link created", {
      uid,
      tenantId,
      amount,
      preferenceId: data.id,
    });

    res.json({
      link: data.init_point,
      sandboxLink: data.sandbox_init_point,
      preferenceId: data.id,
    });
  } catch (error) {
    functions.logger.error("Error creating payment link", error);
    res.status(500).json({ error: "Erro ao gerar link de pagamento" });
  }
});

// ============================================================================
// Helpers
// ============================================================================

function mapMpStatus(mpStatus: string): string {
  const map: Record<string, string> = {
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
  return map[mpStatus] || "pending";
}

function serializeOrder(data: admin.firestore.DocumentData): Record<string, unknown> {
  const serialized: Record<string, unknown> = { ...data };

  // Convert Firestore Timestamps to ISO strings
  const timestampFields = [
    "createdAt", "updatedAt", "estimatedDelivery",
    "paidAt", "paymentReleasedAt", "pixExpiration",
  ];

  for (const field of timestampFields) {
    if (serialized[field] && typeof (serialized[field] as Record<string, unknown>).toDate === "function") {
      serialized[field] = (serialized[field] as admin.firestore.Timestamp).toDate().toISOString();
    }
  }

  // Serialize nested timestamps in statusHistory
  if (Array.isArray(serialized.statusHistory)) {
    serialized.statusHistory = (serialized.statusHistory as Record<string, unknown>[]).map((sh) => ({
      ...sh,
      timestamp: typeof (sh.timestamp as Record<string, unknown>)?.toDate === "function"
        ? (sh.timestamp as admin.firestore.Timestamp).toDate().toISOString()
        : sh.timestamp,
    }));
  }

  // Serialize heldUntil in paymentSplit
  if (serialized.paymentSplit && typeof serialized.paymentSplit === "object") {
    const split = serialized.paymentSplit as Record<string, unknown>;
    if (split.heldUntil && typeof (split.heldUntil as Record<string, unknown>)?.toDate === "function") {
      split.heldUntil = (split.heldUntil as admin.firestore.Timestamp).toDate().toISOString();
    }
  }

  return serialized;
}

export default router;
