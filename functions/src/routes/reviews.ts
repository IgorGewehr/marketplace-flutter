import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Response } from "express";
import { AuthenticatedRequest } from "../middleware/auth";
import { v4 as uuidv4 } from "uuid";

const router = Router();

// ============================================================================
// Reviews — Authenticated Endpoints
// ============================================================================

/**
 * POST /api/reviews
 * Create a product review for a delivered order.
 * Validates: order belongs to user, product is in order, not already reviewed.
 */
router.post("/", async (req, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  const { productId, orderId, rating, comment } = req.body;

  if (!productId || !orderId || !rating) {
    res.status(400).json({ error: "productId, orderId e rating são obrigatórios" });
    return;
  }

  const ratingNum = Number(rating);
  if (isNaN(ratingNum) || ratingNum < 1 || ratingNum > 5) {
    res.status(400).json({ error: "Rating deve ser entre 1 e 5" });
    return;
  }

  try {
    const db = admin.firestore();

    // 1. Validate order exists and belongs to user
    const orderDoc = await db.collection("orders").doc(orderId).get();
    if (!orderDoc.exists) {
      res.status(404).json({ error: "Pedido não encontrado" });
      return;
    }

    const order = orderDoc.data()!;
    if (order.buyerUserId !== uid) {
      res.status(403).json({ error: "Você não tem permissão para avaliar este pedido" });
      return;
    }

    if (order.status !== "delivered") {
      res.status(400).json({ error: "O pedido deve estar entregue para ser avaliado" });
      return;
    }

    // 2. Validate product is in the order
    const items = (order.items as Array<{ productId: string }>) || [];
    const productInOrder = items.some((item) => item.productId === productId);
    if (!productInOrder) {
      res.status(400).json({ error: "Produto não encontrado neste pedido" });
      return;
    }

    // 3. Check for duplicate review — query by orderId (auto-indexed), filter in code
    const existingSnap = await db.collection("reviews")
      .where("orderId", "==", orderId)
      .get();

    const alreadyReviewed = existingSnap.docs.some((doc) => {
      const d = doc.data();
      return d.productId === productId && d.userId === uid;
    });

    if (alreadyReviewed) {
      res.status(409).json({ error: "Você já avaliou este produto para este pedido" });
      return;
    }

    // 4. Get product to retrieve tenantId
    const productDoc = await db.collection("products").doc(productId).get();
    if (!productDoc.exists) {
      res.status(404).json({ error: "Produto não encontrado" });
      return;
    }
    const product = productDoc.data()!;
    const tenantId = product.tenantId as string;

    // 5. Get user info
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() || {};
    const userName = (userData.displayName as string | undefined) || "Usuário";
    const userPhotoURL = (userData.photoURL as string | null | undefined) ?? null;

    // 6. Build and save review
    const reviewId = uuidv4();
    const now = admin.firestore.Timestamp.now();

    const reviewData: Record<string, unknown> = {
      id: reviewId,
      targetId: productId,
      targetType: "product",
      productId,
      tenantId,
      userId: uid,
      userName,
      userPhotoURL,
      rating: Math.round(ratingNum * 2) / 2, // Round to nearest 0.5
      comment: typeof comment === "string" && comment.trim() ? comment.trim() : null,
      orderId,
      isVerifiedPurchase: true,
      helpfulCount: 0,
      reportCount: 0,
      isHidden: false,
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("reviews").doc(reviewId).set(reviewData);

    functions.logger.info("Review created", { reviewId, productId, tenantId, rating: ratingNum, uid });

    res.status(201).json({
      ...reviewData,
      createdAt: now.toDate().toISOString(),
      updatedAt: now.toDate().toISOString(),
    });
  } catch (error) {
    functions.logger.error("Error creating review", error);
    res.status(500).json({ error: "Erro ao criar avaliação" });
  }
});

/**
 * GET /api/reviews/check?orderId=X
 * Returns the list of productIds already reviewed for this order by the current user.
 */
router.get("/check", async (req, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const orderId = req.query.orderId as string | undefined;

  if (!orderId) {
    res.status(400).json({ error: "orderId é obrigatório" });
    return;
  }

  try {
    const db = admin.firestore();

    // Query by orderId only (single-field, auto-indexed), filter by userId in code
    const snap = await db.collection("reviews")
      .where("orderId", "==", orderId)
      .get();

    const reviewedProductIds = snap.docs
      .filter((doc) => doc.data().userId === uid)
      .map((doc) => doc.data().productId as string)
      .filter(Boolean);

    res.json({ reviewedProductIds });
  } catch (error) {
    functions.logger.error("Error checking reviews", error);
    res.status(500).json({ error: "Erro ao verificar avaliações" });
  }
});

export default router;
