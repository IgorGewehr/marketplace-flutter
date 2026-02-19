import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();

// ============================================================================
// Cart Endpoints
// ============================================================================

/**
 * GET /api/cart
 * Get current user's cart.
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const db = admin.firestore();

    // Get cart metadata
    const cartRef = db.collection("carts").doc(uid);
    const cartDoc = await cartRef.get();

    // Get cart items
    const itemsSnap = await cartRef.collection("items").orderBy("addedAt", "desc").get();

    const items = itemsSnap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        productId: data.productId,
        variantId: data.variantId || null,
        name: data.productName || data.name || "",
        imageUrl: data.imageUrl || null,
        quantity: data.quantity || 1,
        price: data.unitPrice || 0,
        tenantId: data.tenantId || "",
      };
    });

    const cart = {
      id: uid,
      userId: uid,
      items,
      totalQuantity: items.reduce((sum, item) => sum + item.quantity, 0),
      subtotal: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
      createdAt: cartDoc.exists
        ? serializeTimestamp(cartDoc.data()!.createdAt)
        : new Date().toISOString(),
      updatedAt: cartDoc.exists
        ? serializeTimestamp(cartDoc.data()!.updatedAt)
        : new Date().toISOString(),
    };

    res.json(cart);
  } catch (error) {
    functions.logger.error("Error fetching cart", error);
    res.status(500).json({ error: "Erro ao buscar carrinho" });
  }
});

/**
 * POST /api/cart/items
 * Add an item to the cart.
 *
 * Body:
 *   productId: string
 *   variantId?: string
 *   quantity: number (default 1)
 */
router.post("/items", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { productId, variantId, quantity = 1 } = req.body;

  if (!productId) {
    res.status(400).json({ error: "productId obrigatorio" });
    return;
  }

  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // Get product info
    const productDoc = await db.collection("products").doc(productId).get();
    if (!productDoc.exists) {
      res.status(404).json({ error: "Produto nao encontrado" });
      return;
    }

    const product = productDoc.data()!;

    // Find variant price if applicable
    let unitPrice = product.price || 0;
    if (variantId && Array.isArray(product.variants)) {
      const variant = product.variants.find((v: Record<string, unknown>) => v.id === variantId);
      if (variant && variant.price) {
        unitPrice = variant.price;
      }
    }

    const cartRef = db.collection("carts").doc(uid);
    const itemsRef = cartRef.collection("items");

    // Check if item already in cart
    let existingQuery: admin.firestore.Query = itemsRef.where("productId", "==", productId);
    if (variantId) {
      existingQuery = existingQuery.where("variantId", "==", variantId);
    }
    const existingSnap = await existingQuery.limit(1).get();

    if (!existingSnap.empty) {
      // Update quantity
      const existingDoc = existingSnap.docs[0];
      const currentQty = existingDoc.data().quantity || 1;
      await existingDoc.ref.update({
        quantity: currentQty + quantity,
        updatedAt: now,
      });
    } else {
      // Add new item
      const itemId = uuidv4();
      await itemsRef.doc(itemId).set({
        id: itemId,
        productId,
        variantId: variantId || null,
        tenantId: product.tenantId,
        productName: product.name,
        imageUrl: product.images?.[0]?.url || null,
        sku: product.sku || null,
        unitPrice,
        quantity,
        addedAt: now,
        updatedAt: now,
      });
    }

    // Ensure cart doc exists
    await cartRef.set({ userId: uid, updatedAt: now, createdAt: now }, { merge: true });

    // Return updated cart
    const updatedItemsSnap = await itemsRef.orderBy("addedAt", "desc").get();
    const items = updatedItemsSnap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        productId: data.productId,
        variantId: data.variantId || null,
        name: data.productName || data.name || "",
        imageUrl: data.imageUrl || null,
        quantity: data.quantity || 1,
        price: data.unitPrice || 0,
        tenantId: data.tenantId || "",
      };
    });

    res.json({
      id: uid,
      userId: uid,
      items,
      totalQuantity: items.reduce((sum, item) => sum + item.quantity, 0),
      subtotal: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
      createdAt: now.toDate().toISOString(),
      updatedAt: now.toDate().toISOString(),
    });
  } catch (error) {
    functions.logger.error("Error adding to cart", error);
    res.status(500).json({ error: "Erro ao adicionar ao carrinho" });
  }
});

/**
 * PATCH /api/cart/items/:id
 * Update cart item quantity.
 *
 * Body:
 *   quantity: number
 */
router.patch("/items/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const itemId = String(req.params.id);
  const { quantity } = req.body;

  if (quantity === undefined || quantity < 0) {
    res.status(400).json({ error: "Quantidade invalida" });
    return;
  }

  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const itemRef = db.collection("carts").doc(uid).collection("items").doc(itemId);
    const itemDoc = await itemRef.get();

    if (!itemDoc.exists) {
      res.status(404).json({ error: "Item nao encontrado no carrinho" });
      return;
    }

    if (quantity === 0) {
      await itemRef.delete();
    } else {
      await itemRef.update({ quantity, updatedAt: now });
    }

    // Return updated cart
    const itemsSnap = await db
      .collection("carts")
      .doc(uid)
      .collection("items")
      .orderBy("addedAt", "desc")
      .get();

    const items = itemsSnap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        productId: data.productId,
        variantId: data.variantId || null,
        name: data.productName || data.name || "",
        imageUrl: data.imageUrl || null,
        quantity: data.quantity || 1,
        price: data.unitPrice || 0,
        tenantId: data.tenantId || "",
      };
    });

    res.json({
      id: uid,
      userId: uid,
      items,
      totalQuantity: items.reduce((sum, item) => sum + item.quantity, 0),
      subtotal: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
      createdAt: now.toDate().toISOString(),
      updatedAt: now.toDate().toISOString(),
    });
  } catch (error) {
    functions.logger.error("Error updating cart item", error);
    res.status(500).json({ error: "Erro ao atualizar item" });
  }
});

/**
 * DELETE /api/cart/items/:id
 * Remove an item from the cart.
 */
router.delete("/items/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const itemId = String(req.params.id);

  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const itemRef = db.collection("carts").doc(uid).collection("items").doc(itemId);
    const itemDoc = await itemRef.get();

    if (!itemDoc.exists) {
      res.status(404).json({ error: "Item nao encontrado no carrinho" });
      return;
    }

    await itemRef.delete();

    // Return updated cart
    const itemsSnap = await db
      .collection("carts")
      .doc(uid)
      .collection("items")
      .orderBy("addedAt", "desc")
      .get();

    const items = itemsSnap.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        productId: data.productId,
        variantId: data.variantId || null,
        name: data.productName || data.name || "",
        imageUrl: data.imageUrl || null,
        quantity: data.quantity || 1,
        price: data.unitPrice || 0,
        tenantId: data.tenantId || "",
      };
    });

    res.json({
      id: uid,
      userId: uid,
      items,
      totalQuantity: items.reduce((sum, item) => sum + item.quantity, 0),
      subtotal: items.reduce((sum, item) => sum + item.price * item.quantity, 0),
      createdAt: now.toDate().toISOString(),
      updatedAt: now.toDate().toISOString(),
    });
  } catch (error) {
    functions.logger.error("Error removing cart item", error);
    res.status(500).json({ error: "Erro ao remover item" });
  }
});

/**
 * DELETE /api/cart
 * Clear the entire cart.
 */
router.delete("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const db = admin.firestore();
    const itemsSnap = await db
      .collection("carts")
      .doc(uid)
      .collection("items")
      .get();

    if (!itemsSnap.empty) {
      const batch = db.batch();
      for (const doc of itemsSnap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
    }

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error clearing cart", error);
    res.status(500).json({ error: "Erro ao limpar carrinho" });
  }
});

// ============================================================================
// Helpers
// ============================================================================

function serializeTimestamp(value: unknown): string {
  if (value && typeof value === "object" && typeof (value as Record<string, unknown>).toDate === "function") {
    return (value as admin.firestore.Timestamp).toDate().toISOString();
  }
  return new Date().toISOString();
}

export default router;
