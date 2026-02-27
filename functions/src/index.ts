import * as admin from "firebase-admin";
import * as functionsV1 from "firebase-functions/v1";
import * as functions from "firebase-functions";
import express from "express";
import cors from "cors";
import rateLimit from "express-rate-limit";

import { validateConfig, config } from "./config";
import { verifyAuth } from "./middleware/auth";
import { handleWebhook } from "./mercadopago/webhook";
import oauthRouter, { handleOAuthCallback } from "./mercadopago/oauth";
import paymentsRouter from "./mercadopago/payments";
import walletRouter from "./mercadopago/withdrawals";
import chatRouter from "./chat/routes";
import deliveryRouter from "./delivery/qrcode";
import addressRouter from "./routes/addresses";
import authRouter from "./routes/auth";
import marketplaceRouter from "./routes/marketplace";
import productsRouter from "./routes/products";
import servicesRouter from "./routes/services";
import notificationsRouter from "./routes/notifications";
import cartRouter from "./routes/cart";
import sellerRouter from "./routes/seller";
import reviewsRouter from "./routes/reviews";
import { releaseHeldPayments } from "./scheduled/release-payments";

// Initialize Firebase Admin
admin.initializeApp();

// Validate config
validateConfig();

// ============================================================================
// Express API App
// ============================================================================

const app = express();

// Trust first proxy hop (Google's load balancer) for correct client IP in rate limiting
app.set("trust proxy", 1);

// CORS - Flutter mobile apps don't need permissive CORS
app.use(cors({ origin: true }));

// Parse JSON bodies
app.use(express.json());

// Rate limiting - general API limit
const apiLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 60, // 60 requests per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Muitas requisições. Tente novamente em instantes." },
});
app.use("/api", apiLimiter);

// Stricter rate limit for order creation
const orderLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 10, // 10 orders per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Limite de criação de pedidos atingido." },
});
app.use("/api/orders", orderLimiter);

// Stricter rate limit for chat messages
const chatLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 30, // 30 messages per minute per IP
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Limite de mensagens atingido." },
});
app.use("/api/chats", chatLimiter);

// Health check (no auth required)
app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// Public key endpoint (no auth required - used for card tokenization)
app.get("/api/mercadopago/public-key", (_req, res) => {
  res.json({ publicKey: config.mercadoPago.publicKey });
});

// OAuth callback endpoint (no auth - called by Mercado Pago redirect)
app.get("/api/mp-oauth-callback", handleOAuthCallback);

// Marketplace browsing (public - no auth required so anyone can browse)
app.use("/api/marketplace", marketplaceRouter);

// Public user profile endpoint (no auth — returns only safe public fields)
app.get("/api/users/:userId/public", async (req: express.Request, res: express.Response) => {
  try {
    const userId = String(req.params.userId);
    if (!userId) {
      res.status(400).json({ error: "userId is required" });
      return;
    }
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    if (!userDoc.exists) {
      res.status(404).json({ error: "User not found" });
      return;
    }
    const data = userDoc.data()!;
    res.json({
      id: userId,
      displayName: data.displayName || data.name || null,
      photoURL: data.photoURL || data.avatarUrl || null,
      type: data.type || "buyer",
      tenantId: data.tenantId || null,
    });
  } catch (error) {
    functions.logger.error("Error fetching public user profile", { error });
    res.status(500).json({ error: "Internal server error" });
  }
});

// ============================================================================
// Authenticated Routes
// ============================================================================

// Apply auth middleware to all routes below
app.use("/api", verifyAuth);

// Auth (register, me, complete-profile, become-seller, fcm tokens)
app.use("/api/auth", authRouter);

// Mercado Pago OAuth
app.use("/api/mercadopago/oauth", oauthRouter);

// Mercado Pago Subscriptions (placeholder for future implementation)
app.get("/api/mercadopago/subscriptions", async (_req: express.Request, res: express.Response) => {
  res.json({ subscription: null });
});

// Orders & Payments
app.use("/api", paymentsRouter);

// Wallet
app.use("/api/wallet", walletRouter);

// Chat
app.use("/api/chats", chatRouter);

// Delivery
app.use("/api/delivery", deliveryRouter);

// Addresses
app.use("/api/addresses", addressRouter);

// Seller Product Management (CRUD)
app.use("/api/products", productsRouter);

// Seller Service Management (CRUD)
app.use("/api/services", servicesRouter);

// Notifications
app.use("/api/notifications", notificationsRouter);

// Cart
app.use("/api/cart", cartRouter);

// Seller Profile & Analytics
app.use("/api/seller", sellerRouter);

// Reviews (create + check)
app.use("/api/reviews", reviewsRouter);

// ============================================================================
// Error handler
// ============================================================================

app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  functions.logger.error("Unhandled error", err);
  res.status(500).json({ error: "Erro interno do servidor" });
});

// ============================================================================
// Exported Cloud Functions
// ============================================================================

/**
 * Main API function - handles all REST endpoints.
 * URL: https://REGION-PROJECT_ID.cloudfunctions.net/api
 */
export const api = functionsV1
  .region("southamerica-east1")
  .runWith({
    timeoutSeconds: 60,
    memory: "512MB" as const,
    minInstances: 0,
    maxInstances: 20,
  })
  .https.onRequest(app);

/**
 * Mercado Pago Webhook handler.
 * Separate function for independent scaling and no auth middleware.
 * URL: https://REGION-PROJECT_ID.cloudfunctions.net/mpWebhook
 *
 * Register this URL in Mercado Pago Dashboard:
 * Integrações > Webhooks > Configurar notificações
 */
export const mpWebhook = functionsV1
  .region("southamerica-east1")
  .runWith({
    timeoutSeconds: 120,
    memory: "256MB" as const,
  })
  .https.onRequest(async (req, res) => {
    // CORS for MP
    res.set("Access-Control-Allow-Origin", "*");
    if (req.method === "OPTIONS") {
      res.set("Access-Control-Allow-Methods", "POST");
      res.set("Access-Control-Allow-Headers", "Content-Type, x-signature, x-request-id");
      res.status(204).send("");
      return;
    }
    await handleWebhook(req as any, res as any);
  });

/**
 * Scheduled function to release held payments.
 * Runs every hour. Releases payments after hold period (default 24h) from payment approval.
 */
export const releasePayments = functionsV1
  .region("southamerica-east1")
  .runWith({
    timeoutSeconds: 300,
    memory: "256MB" as const,
  })
  .pubsub.schedule("every 1 hours")
  .timeZone("America/Sao_Paulo")
  .onRun(async () => {
    await releaseHeldPayments();
  });

/**
 * Firestore trigger: Update review statistics when a new review is created.
 */
export const onReviewCreated = functionsV1
  .region("southamerica-east1")
  .firestore.document("reviews/{reviewId}")
  .onCreate(async (snap: functionsV1.firestore.QueryDocumentSnapshot) => {
    const review = snap.data();
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    try {
      // Update the reviewed entity's stats
      if (review.productId) {
        const productRef = db.collection("products").doc(review.productId);
        await db.runTransaction(async (transaction) => {
          const productSnap = await transaction.get(productRef);
          if (!productSnap.exists) return;

          const product = productSnap.data()!;
          const currentRating = product.rating || product.averageRating || 0;
          const currentCount = product.reviewCount || 0;
          const newCount = currentCount + 1;
          const newRating =
            (currentRating * currentCount + review.rating) / newCount;

          transaction.update(productRef, {
            rating: Math.round(newRating * 10) / 10,
            reviewCount: newCount,
            updatedAt: now,
          });
        });
      }

      // Update seller stats if it's a seller review
      if (review.tenantId) {
        const tenantRef = db.collection("tenants").doc(review.tenantId);
        await db.runTransaction(async (transaction) => {
          const tenantSnap = await transaction.get(tenantRef);
          if (!tenantSnap.exists) return;

          const tenant = tenantSnap.data()!;
          const stats = tenant.marketplaceStats || {};
          const currentRating = stats.rating || stats.averageRating || 0;
          const currentCount = stats.totalReviews || 0;
          const newCount = currentCount + 1;
          const newRating =
            (currentRating * currentCount + review.rating) / newCount;

          transaction.update(tenantRef, {
            "marketplaceStats.rating": Math.round(newRating * 10) / 10,
            "marketplaceStats.totalReviews": newCount,
            updatedAt: now,
          });
        });
      }

      functions.logger.info("Review stats updated", {
        reviewId: snap.id,
        productId: review.productId,
        tenantId: review.tenantId,
        rating: review.rating,
      });
    } catch (error) {
      functions.logger.error("Error updating review stats", error);
    }
  });

/**
 * Firestore trigger: Notify wishlist users when a product price drops.
 */
export const onProductPriceDrop = functionsV1
  .region("southamerica-east1")
  .firestore.document("products/{productId}")
  .onUpdate(async (change: functionsV1.Change<functionsV1.firestore.QueryDocumentSnapshot>) => {
    const before = change.before.data();
    const after = change.after.data();
    const productId = change.after.id;

    // Check if price decreased
    const oldPrice = before.price || 0;
    const newPrice = after.price || 0;

    if (newPrice >= oldPrice || newPrice <= 0) return;

    const discount = Math.round(((oldPrice - newPrice) / oldPrice) * 100);
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    try {
      // Find users with this product in their wishlist
      const wishlistSnap = await db
        .collection("wishlists")
        .where("productId", "==", productId)
        .get();

      if (wishlistSnap.empty) return;

      functions.logger.info(`Price drop detected for product ${productId}`, {
        oldPrice,
        newPrice,
        discount: `${discount}%`,
        wishlistUsers: wishlistSnap.size,
      });

      const { v4: uuidv4 } = await import("uuid");

      for (const wishDoc of wishlistSnap.docs) {
        const wishData = wishDoc.data();
        const userId = wishData.userId;

        // Create notification
        const notifId = uuidv4();
        await db.collection("notifications").doc(notifId).set({
          id: notifId,
          userId,
          title: `Preco baixou ${discount}%!`,
          body: `${after.name || "Produto"} agora por R$ ${newPrice.toFixed(2)}`,
          type: "price_drop",
          data: { productId },
          isRead: false,
          createdAt: now,
        });

        // Send FCM
        try {
          const userDoc = await db.collection("users").doc(userId).get();
          const ud = userDoc.data();
          const fcmTokens = ud?.fcmTokens || (ud?.fcmToken ? [ud.fcmToken] : []);
          for (const token of fcmTokens) {
            try {
              await admin.messaging().send({
                token,
                notification: {
                  title: `Preco baixou ${discount}%!`,
                  body: `${after.name || "Produto"} agora por R$ ${newPrice.toFixed(2)}`,
                },
                data: { type: "price_drop", productId },
                android: { priority: "high" },
                apns: { payload: { aps: { sound: "default" } } },
              });
            } catch { /* token may be invalid */ }
          }
        } catch {
          // Silently fail push notifications
        }
      }
    } catch (error) {
      functions.logger.error("Error processing price drop notification", error);
    }
  });
