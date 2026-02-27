import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { config } from "../config";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";
import { createPayment, getPayment, refundPayment, mpRequest, MpPaymentRequest } from "./client";
import { getValidSellerToken } from "./oauth";

const router = Router();

/**
 * Number of days after payment before auto-confirming delivery.
 * Must match the value in release-payments.ts.
 */
const AUTO_CONFIRM_DAYS = 7;

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
  // Hoisted so the catch block can restore stock if something fails after deduction
  let items: Record<string, unknown>[] = [];
  let tenantId = "";
  // Tracks whether stock was successfully decremented, so we can restore on failure
  let stockDecremented = false;
  // Snapshot of original variant arrays so we can restore them if the order fails later
  const variantSnapshots = new Map<string, unknown[]>();

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

    // Build order items and validate prices against source products
    let subtotal = 0;

    // Collect cart data first, then validate prices server-side
    const cartItems: { doc: admin.firestore.QueryDocumentSnapshot; data: admin.firestore.DocumentData }[] = [];
    for (const doc of cartSnap.docs) {
      cartItems.push({ doc, data: doc.data() });
    }

    // Resolve tenantId from cart items
    for (const { data: item } of cartItems) {
      if (!tenantId) {
        tenantId = item.tenantId || "";
      } else if (item.tenantId && item.tenantId !== tenantId) {
        res.status(400).json({ error: "Todos os itens do carrinho devem ser do mesmo vendedor" });
        return;
      }
    }

    if (!tenantId) {
      res.status(400).json({ error: "Vendedor não identificado nos itens do carrinho" });
      return;
    }

    // Fetch all products to validate prices server-side (prevent cart price manipulation)
    const productIds = [...new Set(cartItems.map(({ data }) => data.productId as string))];
    const productPriceMap = new Map<string, {
      price: number;
      promoPrice?: number;
      name: string;
      variants?: Record<string, unknown>[];
    }>();

    for (const productId of productIds) {
      const productDoc = await db.collection("products").doc(productId).get();
      if (!productDoc.exists) {
        res.status(400).json({ error: `Produto não encontrado: ${productId}` });
        return;
      }
      const productData = productDoc.data()!;
      productPriceMap.set(productId, {
        price: productData.price || 0,
        promoPrice: productData.promoPrice || undefined,
        name: productData.name || "Produto",
        variants: Array.isArray(productData.variants) ? productData.variants as Record<string, unknown>[] : undefined,
      });
    }

    for (const { data: item } of cartItems) {
      const productId = item.productId as string;
      const product = productPriceMap.get(productId);

      if (!product) {
        res.status(400).json({ error: `Produto não encontrado: ${productId}` });
        return;
      }

      // Use server-side price: promo price if available, otherwise regular price
      let serverPrice = product.promoPrice && product.promoPrice > 0
        ? product.promoPrice
        : product.price;

      // If the item has a variantId, override with the variant's price
      const variantId = item.variantId as string | null;
      if (variantId && product.variants) {
        const variant = product.variants.find((v) => v.id === variantId);
        if (variant && typeof variant.price === "number" && variant.price > 0) {
          serverPrice = variant.price as number;
        }
      }

      // Include variant name in the item name for display
      let itemName = product.name;
      if (variantId && product.variants) {
        const variant = product.variants.find((v) => v.id === variantId);
        if (variant?.name) itemName = `${product.name} - ${variant.name}`;
      }

      const quantity = item.quantity || 1;
      const itemTotal = serverPrice * quantity;
      subtotal += itemTotal;

      items.push({
        productId,
        variantId: item.variantId || null,
        name: itemName,
        sku: item.sku || null,
        imageUrl: item.imageUrl || null,
        quantity,
        unitPrice: serverPrice,
        discount: item.discount || 0,
        total: itemTotal,
      });
    }

    // Calculate fees
    const deliveryFee = 0; // No delivery fee on this platform
    const discount = 0; // No discounts/coupons on this platform
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

    // Resolve buyer email: prefer Firebase Auth email (always valid for email/password and Google accounts)
    // over the Firestore document email. Never use a fake placeholder domain.
    let buyerEmail: string | null = userData.email || null;
    if (!buyerEmail) {
      try {
        const authUser = await admin.auth().getUser(uid);
        buyerEmail = authUser.email || null;
      } catch {
        // getUser failed — buyerEmail remains null
      }
    }
    if (!buyerEmail) {
      res.status(400).json({ error: "Email do comprador é obrigatório para pagamento" });
      return;
    }

    const buyerName = userData.displayName || userData.name || "";
    const nameParts = buyerName.trim().split(/\s+/);
    const firstName = nameParts[0] || "Comprador";
    const lastName = nameParts.length > 1 ? nameParts.slice(1).join(" ") : firstName;

    // Resolve buyer CPF/CNPJ and detect type by digit count
    const cpfCnpjDigits = userData.cpfCnpj
      ? String(userData.cpfCnpj).replace(/\D/g, "")
      : null;
    const identificationType = cpfCnpjDigits
      ? (cpfCnpjDigits.length <= 11 ? "CPF" : "CNPJ")
      : null;

    // PIX requires CPF/CNPJ for Brazilian regulations
    if (paymentMethod === "pix" && (!cpfCnpjDigits || cpfCnpjDigits.length < 11)) {
      res.status(400).json({
        error: "Para pagar via PIX é necessário ter CPF cadastrado. Acesse seu perfil e adicione seu CPF antes de continuar.",
        code: "MISSING_IDENTIFICATION",
      });
      return;
    }

    // Idempotency check: prevent duplicate order creation (atomic)
    const idempotencyRef = db.collection("idempotency_keys").doc(idempotencyKey);

    try {
      await db.runTransaction(async (transaction) => {
        const idempotencyDoc = await transaction.get(idempotencyRef);
        if (idempotencyDoc.exists) {
          const existing = idempotencyDoc.data()!;
          if (existing.status === "processing") {
            throw new Error("DUPLICATE_PROCESSING");
          }
          if (existing.status === "completed" && existing.orderId) {
            throw new Error(`DUPLICATE_ORDER:${existing.orderId}`);
          }
        }
        transaction.set(idempotencyRef, {
          orderId,
          status: "processing",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      if (errorMessage === "DUPLICATE_PROCESSING") {
        res.status(409).json({ error: "Pedido já está sendo processado. Aguarde." });
        return;
      }
      if (errorMessage.startsWith("DUPLICATE_ORDER:")) {
        const existingOrderId = errorMessage.split(":")[1];
        const existingOrder = await db.collection("orders").doc(existingOrderId).get();
        if (existingOrder.exists) {
          res.status(201).json(serializeOrder(existingOrder.data()!));
          return;
        }
      }
      throw error;
    }

    // ---- Stock validation and deduction (atomic transaction) ----
    // Validate each item has sufficient stock, then decrement atomically.
    // This prevents race conditions where two buyers purchase the last unit simultaneously.
    try {
      await db.runTransaction(async (transaction) => {
        const productRefs: admin.firestore.DocumentReference[] = [];
        const productDocs: admin.firestore.DocumentSnapshot[] = [];

        // Fetch all product documents within the transaction
        for (const item of items) {
          const productRef = db
            .collection("products")
            .doc(item.productId as string);
          productRefs.push(productRef);
          const productDoc = await transaction.get(productRef);
          productDocs.push(productDoc);
        }

        // Validate stock for all items before making any writes
        for (let i = 0; i < items.length; i++) {
          const item = items[i];
          const productDoc = productDocs[i];

          if (!productDoc.exists) {
            throw new Error(`STOCK_ERROR:Produto não encontrado: ${item.productId}`);
          }

          const product = productDoc.data()!;
          const requestedQty = item.quantity as number;

          // Check root-level quantity
          if ((product.quantity ?? 0) < requestedQty) {
            throw new Error(
              `STOCK_ERROR:Produto '${product.name}' sem estoque suficiente. Disponível: ${product.quantity ?? 0}`
            );
          }

          // If item has a variantId, also validate the variant's quantity
          if (item.variantId) {
            const variants: Record<string, unknown>[] = Array.isArray(product.variants)
              ? (product.variants as Record<string, unknown>[])
              : [];
            const variant = variants.find((v) => v.id === item.variantId || v.variantId === item.variantId);
            if (variant) {
              const variantQty = (variant.quantity as number) ?? 0;
              if (variantQty < requestedQty) {
                throw new Error(
                  `STOCK_ERROR:Produto '${product.name}' (variante) sem estoque suficiente. Disponível: ${variantQty}`
                );
              }
            }
          }
        }

        // Snapshot original variants before decrement for rollback
        for (let i = 0; i < items.length; i++) {
          const productDoc = productDocs[i];
          const product = productDoc.data()!;
          const productId = items[i].productId as string;
          if (Array.isArray(product.variants) && product.variants.length > 0) {
            variantSnapshots.set(productId, product.variants as unknown[]);
          }
        }

        // All validations passed — decrement stock
        for (let i = 0; i < items.length; i++) {
          const item = items[i];
          const productRef = productRefs[i];
          const productDoc = productDocs[i];
          const product = productDoc.data()!;
          const requestedQty = item.quantity as number;

          const updatePayload: Record<string, unknown> = {
            quantity: admin.firestore.FieldValue.increment(-requestedQty),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          // If item has a variant, update that variant's quantity inside the variants array
          if (item.variantId) {
            const variants: Record<string, unknown>[] = Array.isArray(product.variants)
              ? (product.variants as Record<string, unknown>[])
              : [];
            const updatedVariants = variants.map((v) => {
              if (v.id === item.variantId || v.variantId === item.variantId) {
                const currentVariantQty = (v.quantity as number) ?? 0;
                return { ...v, quantity: Math.max(0, currentVariantQty - requestedQty) };
              }
              return v;
            });
            updatePayload.variants = updatedVariants;
          }

          transaction.update(productRef, updatePayload);
        }
      });
    } catch (stockError: unknown) {
      const stockMessage = stockError instanceof Error ? stockError.message : String(stockError);
      if (stockMessage.startsWith("STOCK_ERROR:")) {
        await idempotencyRef.delete();
        res.status(400).json({ error: stockMessage.replace("STOCK_ERROR:", "") });
        return;
      }
      // Re-throw non-stock errors
      throw stockError;
    }
    // Stock successfully decremented — mark so catch block can restore on failure
    stockDecremented = true;

    // Get seller's MP access token for marketplace split
    let sellerAccessToken = "";
    let useMarketplaceSplit = true;
    try {
      sellerAccessToken = await getValidSellerToken(tenantId);
    } catch {
      // Seller not connected to MP - block checkout; restore stock first
      try {
        const restoreBatch = db.batch();
        for (const item of items) {
          const productRef = db
            .collection("products")
            .doc(item.productId as string);
          const restoreData: Record<string, unknown> = {
            quantity: admin.firestore.FieldValue.increment(item.quantity as number),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          // Restore variant array from snapshot
          const originalVariants = variantSnapshots.get(item.productId as string);
          if (originalVariants && originalVariants.length > 0) {
            restoreData.variants = originalVariants;
          }
          restoreBatch.update(productRef, restoreData);
        }
        await restoreBatch.commit();
      } catch (restoreErr) {
        functions.logger.error("Failed to restore stock after seller-not-connected error", restoreErr);
      }
      stockDecremented = false;
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
      // Create PIX payment with 30-min expiration (gives margin over the 15-min UI countdown)
      const pixExpiration = new Date(Date.now() + 30 * 60 * 1000);
      const paymentReq: MpPaymentRequest = {
        transaction_amount: total,
        description: `Pedido ${orderNumber} - Compre Aqui`,
        payment_method_id: "pix",
        date_of_expiration: pixExpiration.toISOString(),
        payer: {
          email: buyerEmail,
          first_name: firstName,
          last_name: lastName,
          identification: cpfCnpjDigits && identificationType
            ? { type: identificationType, number: cpfCnpjDigits }
            : undefined,
        },
        notification_url: webhookUrl,
        external_reference: orderId,
        ...(useMarketplaceSplit ? { application_fee: platformFeeAmount } : {}),
        money_release_days: Math.ceil((AUTO_CONFIRM_DAYS * 24 + config.platform.paymentHoldHours) / 24),
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
      orderData.pixExpiration = admin.firestore.Timestamp.fromDate(pixExpiration);
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
        description: `Pedido ${orderNumber} - Compre Aqui`,
        token: cardTokenId,
        three_d_secure_mode: "optional",
        binary_mode: false, // allows pending status for 3DS challenge
        installments: paymentMethod === "creditCard" ? installments : 1,
        payer: {
          email: buyerEmail,
          first_name: firstName,
          last_name: lastName,
          identification: cpfCnpjDigits && identificationType
            ? { type: identificationType, number: cpfCnpjDigits }
            : undefined,
        },
        notification_url: webhookUrl,
        external_reference: orderId,
        ...(useMarketplaceSplit ? { application_fee: platformFeeAmount } : {}),
        money_release_days: Math.ceil((AUTO_CONFIRM_DAYS * 24 + config.platform.paymentHoldHours) / 24),
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
        const sellerUserId = tenantData?.ownerId || tenantData?.ownerUserId;
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

    // Restore stock for items that were decremented before the failure
    // Only attempt if stock was actually decremented in this request
    if (stockDecremented && items.length > 0 && tenantId) {
      try {
        const restoreBatch = db.batch();
        for (const item of items) {
          const productRef = db
            .collection("products")
            .doc(item.productId as string);
          const restoreData: Record<string, unknown> = {
            quantity: admin.firestore.FieldValue.increment(item.quantity as number),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          // Restore variant array from snapshot
          const originalVariants = variantSnapshots.get(item.productId as string);
          if (originalVariants && originalVariants.length > 0) {
            restoreData.variants = originalVariants;
          }
          restoreBatch.update(productRef, restoreData);
        }
        await restoreBatch.commit();
        functions.logger.info("Stock restored after order creation failure", { orderId, tenantId });
      } catch (restoreErr) {
        functions.logger.error("Failed to restore stock after order failure", restoreErr);
      }
    }

    functions.logger.error("Error creating order", error);

    let clientMessage = "Erro ao criar pedido. Tente novamente.";
    let clientCode = "ORDER_CREATION_FAILED";
    if (error instanceof functions.https.HttpsError) {
      const details = error.details as Record<string, unknown> | undefined;
      const mpMessage = typeof details?.message === "string" ? details.message.toLowerCase() : "";

      // Seller doesn't have PIX key registered in MercadoPago
      if (mpMessage.includes("without key enabled for qr") || mpMessage.includes("qr render")) {
        clientMessage = "O vendedor ainda não habilitou o recebimento via PIX no Mercado Pago. Tente pagar com cartão de crédito.";
        clientCode = "SELLER_PIX_NOT_ENABLED";
      } else {
        const mpStatusMatch = error.message.match(/(\d{3})/);
        const mpStatus = mpStatusMatch ? mpStatusMatch[1] : null;
        if (mpStatus === "400" || mpStatus === "422") {
          clientMessage = "Dados de pagamento inválidos. Verifique suas informações e tente novamente.";
        }
      }
    }
    res.status(500).json({ error: clientMessage, code: clientCode });
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
    if (data.paymentGatewayId && data.tenantId) {
      try {
        // Use seller token first since marketplace payments are created with seller tokens
        const sellerToken = await getValidSellerToken(data.tenantId);
        const payment = await getPayment(data.paymentGatewayId, sellerToken);
        res.json({
          paymentStatus: mapMpStatus(payment.status),
          mpStatus: payment.status,
          mpStatusDetail: payment.status_detail,
        });
        return;
      } catch {
        // Fallback to stored status if seller token fails
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

    // Resolve buyer email: prefer Firebase Auth email, never use a fake placeholder domain.
    let buyerEmail: string | null = (userData.email as string | undefined) || null;
    if (!buyerEmail) {
      try {
        const authUser = await admin.auth().getUser(uid);
        buyerEmail = authUser.email || null;
      } catch {
        // getUser failed — buyerEmail remains null
      }
    }
    if (!buyerEmail) {
      res.status(400).json({ error: "Email do comprador é obrigatório para pagamento" });
      return;
    }

    const buyerName = userData.displayName || userData.name || "";
    const regenNameParts = buyerName.trim().split(/\s+/);
    const regenFirstName = regenNameParts[0] || "Comprador";
    const regenLastName = regenNameParts.length > 1 ? regenNameParts.slice(1).join(" ") : regenFirstName;

    // Resolve CPF/CNPJ and detect type
    const regenCpfCnpjDigits = userData.cpfCnpj
      ? String(userData.cpfCnpj).replace(/\D/g, "")
      : null;
    const regenIdentificationType = regenCpfCnpjDigits
      ? (regenCpfCnpjDigits.length <= 11 ? "CPF" : "CNPJ")
      : null;

    if (!regenCpfCnpjDigits || regenCpfCnpjDigits.length < 11) {
      res.status(400).json({
        error: "Para pagar via PIX é necessário ter CPF cadastrado. Acesse seu perfil e adicione seu CPF antes de continuar.",
        code: "MISSING_IDENTIFICATION",
      });
      return;
    }

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

    // Cancel the previous PIX payment to prevent double-payment
    if (data.paymentGatewayId) {
      try {
        await mpRequest({
          method: "PUT",
          path: `/v1/payments/${data.paymentGatewayId}`,
          accessToken: sellerAccessToken,
          body: { status: "cancelled" },
        });
      } catch (cancelErr) {
        // Log but do not block — the payment may have already expired
        functions.logger.warn("Could not cancel previous PIX payment", { paymentId: data.paymentGatewayId, cancelErr });
      }
    }

    const regenPixExpiration = new Date(Date.now() + 30 * 60 * 1000);
    const paymentReq: MpPaymentRequest = {
      transaction_amount: total,
      description: `Pedido ${orderNumber} - Compre Aqui`,
      payment_method_id: "pix",
      date_of_expiration: regenPixExpiration.toISOString(),
      payer: {
        email: buyerEmail,
        first_name: regenFirstName,
        last_name: regenLastName,
        identification: regenCpfCnpjDigits && regenIdentificationType
          ? { type: regenIdentificationType, number: regenCpfCnpjDigits }
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
      pixExpiration: admin.firestore.Timestamp.fromDate(regenPixExpiration),
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
        functions.logger.error("Failed to refund payment before cancellation", {
          orderId,
          refundError: refundError instanceof Error ? refundError.message : refundError,
        });
        throw new functions.https.HttpsError(
          "internal",
          "Não foi possível processar o estorno. Tente novamente ou entre em contato com o suporte."
        );
      }
    }

    // Restore stock on cancellation (root quantity + variant quantity)
    if (newStatus === "cancelled" && Array.isArray(data.items) && data.items.length > 0 && data.tenantId) {
      try {
        await restoreOrderStock(db, data.items as Record<string, unknown>[]);
        functions.logger.info("Stock restored for cancelled order", { orderId });
      } catch (stockRestoreErr) {
        functions.logger.error("Failed to restore stock for cancelled order", { orderId, error: stockRestoreErr });
        // Do not block the cancellation — log for manual review
      }
    }

    await orderRef.update(updateData);

    const updatedDoc = await orderRef.get();

    // Fire-and-forget: notify buyer (and seller for shipped) about status change
    sendOrderStatusNotification(
      db,
      data,
      orderId,
      newStatus,
      (data.orderNumber as string) || orderId.substring(0, 8)
    );

    res.json(serializeOrder(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error updating order status", error);
    if (error instanceof functions.https.HttpsError) {
      res.status(500).json({ error: error.message });
    } else {
      res.status(500).json({ error: "Erro ao atualizar pedido" });
    }
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

    // Advance order to 'shipped' if currently in an advanceable status
    const advanceableStatuses = ["confirmed", "processing", "preparing", "ready"];
    const shouldAdvance = advanceableStatuses.includes(data.status);
    if (shouldAdvance) {
      updateData.status = "shipped";
      updateData.shippedAt = now;
      updateData.statusHistory = admin.firestore.FieldValue.arrayUnion({
        status: "shipped",
        timestamp: now,
        note: `Código de rastreamento adicionado: ${trackingCode.trim()}`,
        userId: uid,
      });
    }

    await orderRef.update(updateData);

    const updatedDoc = await orderRef.get();
    res.json(serializeOrder(updatedDoc.data()!));

    functions.logger.info("Tracking code added to order", {
      orderId,
      trackingCode: trackingCode.trim(),
      shippingCompany: shippingCompany || null,
      tenantId,
      advancedToShipped: shouldAdvance,
    });

    // Notify buyer that order has been shipped (fire-and-forget)
    if (shouldAdvance) {
      sendOrderStatusNotification(
        db,
        data,
        orderId,
        "shipped",
        (data.orderNumber as string) || orderId.substring(0, 8)
      );
    }
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
            title: description || "Pagamento - Compre Aqui",
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

/**
 * POST /api/orders/:id/dispute
 * Buyer reports a problem with an order.
 * If the payment is still within the refund window, triggers a full refund.
 *
 * Body:
 *   reason: string (required) - Description of the problem
 */
router.post("/orders/:id/dispute", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const orderId = String(req.params.id);
  const { reason } = req.body;

  if (!reason || !reason.trim()) {
    res.status(400).json({ error: "Descreva o problema encontrado" });
    return;
  }

  try {
    const db = admin.firestore();
    const orderRef = db.collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      res.status(404).json({ error: "Pedido não encontrado" });
      return;
    }

    const data = orderDoc.data()!;

    // Only buyer can dispute
    if (data.buyerUserId !== uid) {
      res.status(403).json({ error: "Apenas o comprador pode reportar problemas" });
      return;
    }

    // Order must be in a disputable state: shipped or delivered (not pending, confirmed, cancelled, or already disputed)
    const disputableStatuses = ["shipped", "delivered", "out_for_delivery"];
    if (!disputableStatuses.includes(data.status)) {
      res.status(400).json({
        error: "Só é possível reportar problema em pedidos que já foram enviados ou entregues",
      });
      return;
    }

    // Can only dispute paid orders that haven't been released yet
    if (data.paymentStatus !== "paid") {
      res.status(400).json({ error: "Não é possível disputar este pedido: pagamento não confirmado" });
      return;
    }

    if (data.paymentSplit?.status === "released") {
      res.status(400).json({
        error: "O pagamento já foi liberado. Entre em contato com o suporte para assistência.",
      });
      return;
    }

    // Already disputed?
    if (data.disputeStatus || data.status === "disputed") {
      res.status(400).json({ error: "Já existe uma disputa aberta para este pedido" });
      return;
    }

    const mpPaymentId = data.paymentSplit?.mpPaymentId || data.paymentGatewayId;
    if (!mpPaymentId) {
      res.status(400).json({ error: "ID de pagamento não encontrado no pedido" });
      return;
    }

    // ---- Step 1: Issue automatic full refund via Mercado Pago ----
    // This must succeed before we update anything in Firestore.
    let refundToken: string;
    try {
      refundToken = await getValidSellerToken(data.tenantId);
    } catch {
      refundToken = config.mercadoPago.accessToken;
    }

    try {
      await refundPayment(
        mpPaymentId,
        refundToken,
        `dispute-refund-${orderId}`
      );
      functions.logger.info("Refund issued for disputed order", { orderId, mpPaymentId });
    } catch (refundError) {
      functions.logger.error("MP refund failed for dispute", { orderId, mpPaymentId, error: refundError });
      res.status(502).json({
        error: "Falha ao processar o reembolso no Mercado Pago. Tente novamente ou entre em contato com o suporte.",
      });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const orderNumber = data.orderNumber || orderId.substring(0, 8);
    const sellerAmount = data.paymentSplit?.sellerAmount || 0;

    // ---- Step 2: Update order and revert seller wallet atomically ----
    const walletRef = db.collection("wallets").doc(data.tenantId as string);

    await db.runTransaction(async (transaction) => {
      const freshOrder = await transaction.get(orderRef);
      if (!freshOrder.exists) return;

      // Update order to disputed + refunded
      transaction.update(orderRef, {
        status: "disputed",
        paymentStatus: "refunded",
        "paymentSplit.status": "refunded",
        disputeStatus: "refunded",
        disputeReason: reason.trim(),
        disputedAt: now,
        disputeOpenedAt: now,
        disputeOpenedBy: uid,
        updatedAt: now,
        statusHistory: admin.firestore.FieldValue.arrayUnion({
          status: "disputed",
          timestamp: now,
          note: `Reembolso solicitado pelo comprador: ${reason.trim()}`,
          userId: uid,
        }),
      });

      // Revert seller wallet: reduce the held/pending amount
      const walletSnap = await transaction.get(walletRef);
      if (walletSnap.exists && sellerAmount > 0) {
        const walletData = walletSnap.data()!;
        const splitStatus = data.paymentSplit?.status as string | undefined;

        if (splitStatus === "released") {
          // Should not reach here due to earlier guard, but handle defensively
          const currentAvailable = walletData.balance?.available || 0;
          transaction.update(walletRef, {
            "balance.available": Math.max(0, currentAvailable - sellerAmount),
            updatedAt: now,
          });
        } else {
          // Still held/pending — reduce the pending balance and total
          const currentPending = walletData.balance?.pending || 0;
          transaction.update(walletRef, {
            "balance.pending": Math.max(0, currentPending - sellerAmount),
            "balance.total": Math.max(0, (walletData.balance?.total || 0) - sellerAmount),
            updatedAt: now,
          });
        }
      }
    });

    // ---- Step 2.5: Restore stock (root + variant quantities) ----
    if (Array.isArray(data.items) && data.items.length > 0) {
      try {
        await restoreOrderStock(db, data.items as Record<string, unknown>[]);
        functions.logger.info("Stock restored for disputed order", { orderId });
      } catch (stockRestoreErr) {
        functions.logger.error("Failed to restore stock for disputed order", { orderId, error: stockRestoreErr });
        // Non-blocking — log for manual review
      }
    }

    // ---- Step 3: Create dispute record for audit trail ----
    const disputeData = {
      orderId,
      buyerUserId: uid,
      sellerTenantId: data.tenantId,
      reason: reason.trim(),
      status: "refunded",
      mpPaymentId,
      refundedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      resolvedAt: null, // Will be set when support resolves the dispute
      resolution: "automatic_refund",
    };
    await db.collection("disputes").add(disputeData);

    // ---- Step 4: Notify seller ----
    const tenantDoc = await db.collection("tenants").doc(data.tenantId as string).get();
    const ownerId = tenantDoc.data()?.ownerId || tenantDoc.data()?.ownerUserId;

    if (ownerId) {
      const notifId = uuidv4();
      await db.collection("notifications").doc(notifId).set({
        id: notifId,
        userId: ownerId,
        title: "Reembolso solicitado",
        body: `Pedido #${orderNumber} foi reembolsado pelo comprador. O valor será devolvido ao comprador pelo Mercado Pago.`,
        type: "order_disputed",
        data: { orderId },
        isRead: false,
        createdAt: now,
      });

      // Send FCM push to seller
      try {
        const sellerUserDoc = await db.collection("users").doc(ownerId).get();
        const sellerTokens = sellerUserDoc.data()?.fcmTokens;
        if (Array.isArray(sellerTokens) && sellerTokens.length > 0) {
          for (const token of sellerTokens) {
            try {
              await admin.messaging().send({
                token,
                notification: {
                  title: "Reembolso solicitado",
                  body: `Pedido #${orderNumber} foi reembolsado pelo comprador.`,
                },
                data: { type: "order_disputed", orderId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
              });
            } catch { /* token may be invalid */ }
          }
        }
      } catch (pushErr) {
        functions.logger.warn("Failed to send dispute push to seller", pushErr);
      }
    }

    functions.logger.info("Dispute processed with automatic refund", { orderId, orderNumber, mpPaymentId });

    res.status(200).json({
      message: "Reembolso processado com sucesso. O valor será devolvido ao seu método de pagamento.",
      status: "refunded",
    });
  } catch (error) {
    functions.logger.error("Error processing dispute", error);
    res.status(500).json({ error: "Erro ao processar disputa" });
  }
});

// ============================================================================
// Helpers
// ============================================================================

/**
 * Send in-app notifications and FCM push messages to the buyer (and optionally
 * the seller) when the seller manually updates an order's status.
 *
 * Called fire-and-forget — errors are swallowed so they never block the response.
 */
async function sendOrderStatusNotification(
  db: admin.firestore.Firestore,
  orderData: Record<string, unknown>,
  orderId: string,
  newStatus: string,
  orderNumber: string
): Promise<void> {
  try {
    const buyerUserId = orderData.buyerUserId as string;
    const tenantId = orderData.tenantId as string;
    const now = admin.firestore.Timestamp.now();

    // Map each supported status to its buyer-facing notification content
    const statusNotifications: Record<string, { title: string; body: string; type: string }> = {
      confirmed: {
        title: "Pedido confirmado!",
        body: `Pedido #${orderNumber} foi confirmado pelo vendedor.`,
        type: "order_confirmed",
      },
      preparing: {
        title: "Pedido em preparação",
        body: `Pedido #${orderNumber} está sendo preparado pelo vendedor.`,
        type: "order_preparing",
      },
      ready: {
        title: "Pedido pronto!",
        body: `Pedido #${orderNumber} está pronto para envio.`,
        type: "order_ready",
      },
      shipped: {
        title: "Pedido enviado!",
        body: `Pedido #${orderNumber} foi enviado pelo vendedor.`,
        type: "order_shipped",
      },
      cancelled: {
        title: "Pedido cancelado",
        body: `Pedido #${orderNumber} foi cancelado.`,
        type: "order_cancelled",
      },
    };

    const notif = statusNotifications[newStatus];
    if (!notif) {
      // No notification defined for this transition — nothing to do
      return;
    }

    // --- Notify buyer ---
    if (buyerUserId) {
      // Persist in-app notification
      const buyerNotifId = uuidv4();
      await db.collection("notifications").doc(buyerNotifId).set({
        id: buyerNotifId,
        userId: buyerUserId,
        title: notif.title,
        body: notif.body,
        type: notif.type,
        data: { orderId },
        isRead: false,
        createdAt: now,
      });

      // Send FCM push to buyer
      try {
        const buyerUserDoc = await db.collection("users").doc(buyerUserId).get();
        const buyerUserData = buyerUserDoc.data();
        const fcmTokens: string[] =
          buyerUserData?.fcmTokens ||
          (buyerUserData?.fcmToken ? [buyerUserData.fcmToken] : []);

        for (const token of fcmTokens) {
          try {
            await admin.messaging().send({
              token,
              notification: { title: notif.title, body: notif.body },
              data: { type: notif.type, orderId },
              android: { priority: "high" },
              apns: { payload: { aps: { sound: "default" } } },
            });
          } catch { /* token may be invalid */ }
        }
      } catch (pushErr) {
        functions.logger.warn("Failed to send buyer push for order status change", { orderId, newStatus, pushErr });
      }
    }

    // --- For 'shipped': also notify the seller as a confirmation ---
    if (newStatus === "shipped" && tenantId) {
      let sellerUserId: string | null = null;
      try {
        const tenantDoc = await db.collection("tenants").doc(tenantId).get();
        sellerUserId = tenantDoc.data()?.ownerId || tenantDoc.data()?.ownerUserId || null;
      } catch {
        functions.logger.warn("sendOrderStatusNotification: Failed to resolve seller UID", { tenantId });
      }

      if (sellerUserId) {
        const sellerNotifTitle = "Pedido marcado como enviado";
        const sellerNotifBody = `Pedido #${orderNumber} foi marcado como enviado.`;
        const sellerNotifType = "order_shipped_confirm";

        const sellerNotifId = uuidv4();
        await db.collection("notifications").doc(sellerNotifId).set({
          id: sellerNotifId,
          userId: sellerUserId,
          title: sellerNotifTitle,
          body: sellerNotifBody,
          type: sellerNotifType,
          data: { orderId },
          isRead: false,
          createdAt: now,
        });

        try {
          const sellerUserDoc = await db.collection("users").doc(sellerUserId).get();
          const sellerUserData = sellerUserDoc.data();
          const sellerFcmTokens: string[] =
            sellerUserData?.fcmTokens ||
            (sellerUserData?.fcmToken ? [sellerUserData.fcmToken] : []);

          for (const token of sellerFcmTokens) {
            try {
              await admin.messaging().send({
                token,
                notification: { title: sellerNotifTitle, body: sellerNotifBody },
                data: { type: sellerNotifType, orderId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
              });
            } catch { /* token may be invalid */ }
          }
        } catch (pushErr) {
          functions.logger.warn("Failed to send seller push for shipped order", { orderId, pushErr });
        }
      }
    }
  } catch (error) {
    functions.logger.warn("sendOrderStatusNotification: unexpected error", { orderId, newStatus, error });
  }
}

/**
 * Restore stock (root quantity + variant quantity) for all items in an order.
 * Used after cancellation, refund, or chargeback.
 * Groups items by productId and uses a Firestore transaction to atomically
 * increment both the root `quantity` field and each variant's `quantity`
 * inside the `variants` array.
 */
export async function restoreOrderStock(
  db: admin.firestore.Firestore,
  items: Record<string, unknown>[]
): Promise<void> {
  // Group items by productId (an order may have multiple items from the same product with different variants)
  const grouped = new Map<string, { qty: number; variantId: string | null }[]>();
  for (const item of items) {
    if (!item.productId) continue;
    const pid = item.productId as string;
    if (!grouped.has(pid)) grouped.set(pid, []);
    grouped.get(pid)!.push({
      qty: (item.quantity as number) || 0,
      variantId: (item.variantId as string) || null,
    });
  }

  await db.runTransaction(async (transaction) => {
    // Read all products first (Firestore transactions require all reads before writes)
    const productSnaps = new Map<string, admin.firestore.DocumentSnapshot>();
    for (const productId of grouped.keys()) {
      const ref = db.collection("products").doc(productId);
      productSnaps.set(productId, await transaction.get(ref));
    }

    // Now write updates
    for (const [productId, restoreItems] of grouped.entries()) {
      const snap = productSnaps.get(productId);
      if (!snap || !snap.exists) continue;

      const productData = snap.data()!;
      const totalQtyRestore = restoreItems.reduce((sum, ri) => sum + ri.qty, 0);

      const updatePayload: Record<string, unknown> = {
        quantity: (productData.quantity ?? 0) + totalQtyRestore,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Restore variant quantities if the product has variants
      const variants: Record<string, unknown>[] = Array.isArray(productData.variants)
        ? (productData.variants as Record<string, unknown>[])
        : [];

      if (variants.length > 0) {
        const updatedVariants = variants.map((v) => {
          const match = restoreItems.find((ri) => ri.variantId && (ri.variantId === v.id || ri.variantId === v.variantId));
          if (match) {
            return { ...v, quantity: ((v.quantity as number) ?? 0) + match.qty };
          }
          return v;
        });
        updatePayload.variants = updatedVariants;
      }

      transaction.update(db.collection("products").doc(productId), updatePayload);
    }
  });
}

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

/**
 * Returns true when an order has a pending action the seller must take:
 *  - status 'confirmed'  → needs to be prepared and shipped
 *  - status 'pending' with paymentStatus 'paid' → needs seller confirmation
 */
function requiresSellerAction(order: Record<string, unknown>): boolean {
  return (
    order.status === "confirmed" ||
    (order.status === "pending" && order.paymentStatus === "paid")
  );
}

function serializeOrder(data: admin.firestore.DocumentData): Record<string, unknown> {
  const serialized: Record<string, unknown> = { ...data };

  // Convert Firestore Timestamps to ISO strings
  const timestampFields = [
    "createdAt", "updatedAt", "estimatedDelivery",
    "paidAt", "paymentReleasedAt", "pixExpiration",
    "deliveryConfirmedAt", "disputeOpenedAt", "disputedAt",
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

  // Computed helper field: true when this order needs an action from the seller
  serialized.requiresSellerAction = requiresSellerAction(serialized);

  return serialized;
}

/**
 * GET /api/payments/installments
 * Get real installment options from Mercado Pago for a given amount and card bin.
 *
 * Query params:
 *   amount: number (required) - total amount in BRL
 *   bin: string (required) - first 6 digits of the card
 *   payment_type_id?: string - defaults to 'credit_card'
 */
router.get("/payments/installments", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const amount = parseFloat(String(req.query.amount || "0"));
  const bin = String(req.query.bin || "").replace(/\D/g, "").substring(0, 6);

  if (!amount || amount <= 0) {
    res.status(400).json({ error: "Valor inválido" });
    return;
  }

  if (!bin || bin.length < 6) {
    res.status(400).json({ error: "BIN do cartão inválido (primeiros 6 dígitos)" });
    return;
  }

  try {
    // Use the platform access token to query installments
    // MP installments API doesn't require seller token - uses platform token
    const mpAccessToken = config.mercadoPago.accessToken;

    const url = new URL("https://api.mercadopago.com/v1/payment_methods/installments");
    url.searchParams.set("bin", bin);
    url.searchParams.set("amount", amount.toFixed(2));

    const mpResponse = await fetch(url.toString(), {
      method: "GET",
      headers: {
        Authorization: `Bearer ${mpAccessToken}`,
        "Content-Type": "application/json",
      },
    });

    if (!mpResponse.ok) {
      // Fallback: return simple installments without fees
      functions.logger.warn("MP installments API failed, returning fallback", {
        status: mpResponse.status,
        bin,
        amount,
      });
      const fallback = Array.from({ length: 12 }, (_, i) => ({
        installments: i + 1,
        installmentAmount: parseFloat((amount / (i + 1)).toFixed(2)),
        totalAmount: amount,
        recommendedMessage: i === 0
          ? `1x de R$ ${amount.toFixed(2)} (à vista)`
          : `${i + 1}x de R$ ${(amount / (i + 1)).toFixed(2)}`,
        interestFree: true,
      }));
      res.json(fallback);
      return;
    }

    const data = await mpResponse.json() as Record<string, unknown>[];

    if (!Array.isArray(data) || data.length === 0) {
      res.status(404).json({ error: "Nenhuma opção de parcelamento disponível" });
      return;
    }

    // data is array of payment method objects, each with payer_costs
    const allInstallments: {
      installments: number;
      installmentAmount: number;
      totalAmount: number;
      recommendedMessage: string;
      interestFree: boolean;
    }[] = [];

    for (const method of data) {
      const payerCosts = (method as Record<string, unknown>).payer_costs as Record<string, unknown>[];
      if (!Array.isArray(payerCosts)) continue;

      for (const cost of payerCosts) {
        const installments = cost.installments as number;
        const installmentAmount = cost.installment_amount as number;
        const totalAmount = cost.total_amount as number;
        const recommendedMessage = cost.recommended_message as string;
        const interestFree = (cost.installment_rate as number) === 0;

        // Deduplicate by installments number (take first occurrence)
        if (!allInstallments.find((i) => i.installments === installments)) {
          allInstallments.push({
            installments,
            installmentAmount: parseFloat(installmentAmount.toFixed(2)),
            totalAmount: parseFloat(totalAmount.toFixed(2)),
            recommendedMessage: recommendedMessage || (
              installments === 1
                ? `1x de R$ ${installmentAmount.toFixed(2)} (à vista)`
                : `${installments}x de R$ ${installmentAmount.toFixed(2)}`
            ),
            interestFree,
          });
        }
      }
    }

    // Sort by installments ascending
    allInstallments.sort((a, b) => a.installments - b.installments);

    // Always ensure at minimum 1x option exists
    if (allInstallments.length === 0) {
      allInstallments.push({
        installments: 1,
        installmentAmount: amount,
        totalAmount: amount,
        recommendedMessage: `1x de R$ ${amount.toFixed(2)} (à vista)`,
        interestFree: true,
      });
    }

    functions.logger.info("Installments fetched from MP", {
      uid,
      amount,
      bin,
      count: allInstallments.length,
    });

    res.json(allInstallments);
  } catch (error) {
    functions.logger.error("Error fetching installments", error);
    // Fallback: return simple installments without fees on error
    const fallback = Array.from({ length: 12 }, (_, i) => ({
      installments: i + 1,
      installmentAmount: parseFloat((amount / (i + 1)).toFixed(2)),
      totalAmount: amount,
      recommendedMessage: i === 0
        ? `1x de R$ ${amount.toFixed(2)} (à vista)`
        : `${i + 1}x de R$ ${(amount / (i + 1)).toFixed(2)}`,
      interestFree: true,
    }));
    res.json(fallback);
  }
});

export default router;
