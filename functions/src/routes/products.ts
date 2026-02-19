import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";

const router = Router();

// ============================================================================
// Seller Product Management (CRUD)
// ============================================================================

/**
 * GET /api/products
 * List seller's own products.
 *
 * Query params: page, limit, status
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
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
      .collection("products")
      .where("tenantId", "==", tenantId)
      .orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    const offset = (page - 1) * limit;
    const productsSnap = await query.offset(offset).limit(limit).get();

    const products = productsSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }));

    res.json({
      products,
      total,
      page,
      limit,
      hasMore: offset + limit < total,
    });
  } catch (error) {
    functions.logger.error("Error fetching seller products", error);
    res.status(500).json({ error: "Erro ao buscar produtos" });
  }
});

/**
 * POST /api/products
 * Create a new product.
 *
 * Body: Product fields (name, description, price, categoryId, etc.)
 */
router.post("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  const {
    name, description, shortDescription, categoryId, subcategoryId,
    tags, images, price, compareAtPrice, costPrice, sku, barcode,
    quantity, trackInventory, hasVariants, variants,
    visibility, ncm, cfop, location,
  } = req.body;

  if (!name || price === undefined || price === null) {
    res.status(400).json({ error: "Nome e preco sao obrigatorios" });
    return;
  }

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const productId = uuidv4();

    const productData: Record<string, unknown> = {
      id: productId,
      tenantId,
      name,
      description: description || "",
      shortDescription: shortDescription || null,
      categoryId: categoryId || "",
      subcategoryId: subcategoryId || null,
      tags: tags || [],
      images: images || [],
      price: parseFloat(price) || 0,
      compareAtPrice: compareAtPrice ? parseFloat(compareAtPrice) : null,
      costPrice: costPrice ? parseFloat(costPrice) : null,
      sku: sku || null,
      barcode: barcode || null,
      quantity: quantity !== undefined ? parseInt(quantity) : null,
      trackInventory: trackInventory ?? true,
      hasVariants: hasVariants ?? false,
      variants: variants || [],
      visibility: visibility || "both",
      status: "active",
      ncm: ncm || null,
      cfop: cfop || null,
      location: location || null,
      marketplaceStats: {
        views: 0,
        favorites: 0,
        sales: 0,
        rating: 0,
        reviewCount: 0,
      },
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("products").doc(productId).set(productData);

    // Update tenant product count
    await db.collection("tenants").doc(tenantId).update({
      "marketplaceStats.totalProducts": admin.firestore.FieldValue.increment(1),
      updatedAt: now,
    });

    functions.logger.info("Product created", { uid, productId, tenantId });

    res.status(201).json(serializeTimestamps(productData));
  } catch (error) {
    functions.logger.error("Error creating product", error);
    res.status(500).json({ error: "Erro ao criar produto" });
  }
});

/**
 * PATCH /api/products/:id
 * Update an existing product.
 */
router.patch("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const productId = String(req.params.id);

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const productRef = db.collection("products").doc(productId);
    const productDoc = await productRef.get();

    if (!productDoc.exists) {
      res.status(404).json({ error: "Produto nao encontrado" });
      return;
    }

    if (productDoc.data()!.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const updateData: Record<string, unknown> = { updatedAt: now };

    const allowedFields = [
      "name", "description", "shortDescription", "categoryId", "subcategoryId",
      "tags", "images", "price", "compareAtPrice", "costPrice", "sku", "barcode",
      "quantity", "trackInventory", "hasVariants", "variants",
      "visibility", "status", "ncm", "cfop", "location",
    ];

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        let value = req.body[field];
        if (field === "price" || field === "compareAtPrice" || field === "costPrice") {
          value = value !== null ? parseFloat(value) : null;
        }
        if (field === "quantity") {
          value = value !== null ? parseInt(value) : null;
        }
        updateData[field] = value;
      }
    }

    await productRef.update(updateData);

    const updatedDoc = await productRef.get();
    res.json({ id: updatedDoc.id, ...serializeTimestamps(updatedDoc.data()!) });
  } catch (error) {
    functions.logger.error("Error updating product", error);
    res.status(500).json({ error: "Erro ao atualizar produto" });
  }
});

/**
 * DELETE /api/products/:id
 * Delete a product (soft delete by setting status to archived).
 */
router.delete("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const productId = String(req.params.id);

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const productRef = db.collection("products").doc(productId);
    const productDoc = await productRef.get();

    if (!productDoc.exists) {
      res.status(404).json({ error: "Produto nao encontrado" });
      return;
    }

    if (productDoc.data()!.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    await productRef.update({
      status: "archived",
      updatedAt: now,
    });

    // Decrement tenant product count
    await db.collection("tenants").doc(tenantId).update({
      "marketplaceStats.totalProducts": admin.firestore.FieldValue.increment(-1),
      updatedAt: now,
    });

    functions.logger.info("Product deleted", { uid, productId, tenantId });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error deleting product", error);
    res.status(500).json({ error: "Erro ao excluir produto" });
  }
});

// ============================================================================
// Helpers
// ============================================================================

function serializeTimestamps(data: admin.firestore.DocumentData): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (value && typeof value === "object" && typeof value.toDate === "function") {
      result[key] = value.toDate().toISOString();
    } else if (value && typeof value === "object" && !Array.isArray(value)) {
      result[key] = serializeTimestamps(value as admin.firestore.DocumentData);
    } else {
      result[key] = value;
    }
  }
  return result;
}

export default router;
