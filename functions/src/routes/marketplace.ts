import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";

const router = Router();

// ============================================================================
// Marketplace Public Endpoints (browsing products, services, categories)
// ============================================================================

/**
 * GET /api/marketplace/products
 * List products with pagination and filters.
 *
 * Query params:
 *   page, limit, categoryId, tenantId, search, minPrice, maxPrice, sortBy, sortOrder
 */
router.get("/products", async (req: Request, res: Response): Promise<void> => {
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);
  const categoryId = req.query.categoryId ? String(req.query.categoryId) : undefined;
  const tenantId = req.query.tenantId ? String(req.query.tenantId) : undefined;
  const search = req.query.search ? String(req.query.search).toLowerCase() : undefined;
  const minPrice = req.query.minPrice ? parseFloat(String(req.query.minPrice)) : undefined;
  const maxPrice = req.query.maxPrice ? parseFloat(String(req.query.maxPrice)) : undefined;
  const sortBy = req.query.sortBy ? String(req.query.sortBy) : "createdAt";
  const sortOrder = req.query.sortOrder === "asc" ? "asc" : "desc";

  try {
    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("products")
      .where("status", "==", "active");

    if (categoryId) {
      query = query.where("categoryId", "==", categoryId);
    }

    if (tenantId) {
      query = query.where("tenantId", "==", tenantId);
    }

    if (minPrice !== undefined) {
      query = query.where("price", ">=", minPrice);
    }

    if (maxPrice !== undefined) {
      query = query.where("price", "<=", maxPrice);
    }

    // Sort
    if (sortBy === "price") {
      query = query.orderBy("price", sortOrder);
    } else if (sortBy === "name") {
      query = query.orderBy("name", sortOrder);
    } else {
      query = query.orderBy("createdAt", sortOrder);
    }

    // Get total count
    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    // Paginate
    const offset = (page - 1) * limit;
    const productsSnap = await query.offset(offset).limit(limit).get();

    let products = productsSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);

    // Client-side text search filter (Firestore doesn't support full-text search)
    if (search) {
      products = products.filter((p) => {
        const name = String(p.name || "").toLowerCase();
        const desc = String(p.description || "").toLowerCase();
        const tags = Array.isArray(p.tags) ? p.tags.join(" ").toLowerCase() : "";
        return name.includes(search) || desc.includes(search) || tags.includes(search);
      });
    }

    res.json({
      products,
      total: search ? products.length : total,
      page,
      limit,
      hasMore: offset + limit < (search ? products.length : total),
    });
  } catch (error) {
    functions.logger.error("Error fetching products", error);
    res.status(500).json({ error: "Erro ao buscar produtos" });
  }
});

/**
 * GET /api/marketplace/products/featured
 * Get featured products (most popular or promoted).
 */
router.get("/products/featured", async (req: Request, res: Response): Promise<void> => {
  const limit = Math.min(parseInt(String(req.query.limit || "10")), 30);

  try {
    const db = admin.firestore();
    const productsSnap = await db
      .collection("products")
      .where("status", "==", "active")
      .orderBy("marketplaceStats.sales", "desc")
      .limit(limit)
      .get();

    // Fallback: if no products have sales stats, get recent ones
    let products = productsSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);

    if (products.length === 0) {
      const fallbackSnap = await db
        .collection("products")
        .where("status", "==", "active")
        .orderBy("createdAt", "desc")
        .limit(limit)
        .get();
      products = fallbackSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);
    }

    res.json({ products });
  } catch (error) {
    functions.logger.error("Error fetching featured products", error);
    res.status(500).json({ error: "Erro ao buscar produtos em destaque" });
  }
});

/**
 * GET /api/marketplace/products/recent
 * Get recently added products.
 */
router.get("/products/recent", async (req: Request, res: Response): Promise<void> => {
  const limit = Math.min(parseInt(String(req.query.limit || "10")), 30);

  try {
    const db = admin.firestore();
    const productsSnap = await db
      .collection("products")
      .where("status", "==", "active")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const products = productsSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);

    res.json({ products });
  } catch (error) {
    functions.logger.error("Error fetching recent products", error);
    res.status(500).json({ error: "Erro ao buscar produtos recentes" });
  }
});

/**
 * GET /api/marketplace/products/:id
 * Get product details by ID.
 */
router.get("/products/:id", async (req: Request, res: Response): Promise<void> => {
  const productId = String(req.params.id);

  try {
    const db = admin.firestore();
    const productDoc = await db.collection("products").doc(productId).get();

    if (!productDoc.exists) {
      res.status(404).json({ error: "Produto nao encontrado" });
      return;
    }

    // Increment view count
    await db.collection("products").doc(productId).update({
      "marketplaceStats.views": admin.firestore.FieldValue.increment(1),
    });

    res.json({ id: productDoc.id, ...serializeTimestamps(productDoc.data()!) });
  } catch (error) {
    functions.logger.error("Error fetching product", error);
    res.status(500).json({ error: "Erro ao buscar produto" });
  }
});

/**
 * GET /api/marketplace/categories
 * Get product categories.
 */
router.get("/categories", async (req: Request, res: Response): Promise<void> => {
  try {
    const db = admin.firestore();
    const categoriesSnap = await db
      .collection("categories")
      .where("isActive", "==", true)
      .orderBy("order", "asc")
      .get();

    const categories = categoriesSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);

    res.json({ categories });
  } catch (error) {
    functions.logger.error("Error fetching categories", error);
    res.status(500).json({ error: "Erro ao buscar categorias" });
  }
});

/**
 * GET /api/marketplace/search
 * Search products by text query.
 */
router.get("/search", async (req: Request, res: Response): Promise<void> => {
  const q = req.query.q ? String(req.query.q).toLowerCase() : "";
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);
  const categoryId = req.query.categoryId ? String(req.query.categoryId) : undefined;

  if (!q) {
    res.json({ products: [], total: 0, page, limit, hasMore: false });
    return;
  }

  try {
    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("products")
      .where("status", "==", "active")
      .orderBy("createdAt", "desc");

    if (categoryId) {
      query = query.where("categoryId", "==", categoryId);
    }

    // Firestore doesn't support full-text search, so we fetch and filter client-side
    const allSnap = await query.limit(500).get();

    let results = allSnap.docs
      .map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>)
      .filter((p) => {
        const name = String(p.name || "").toLowerCase();
        const desc = String(p.description || "").toLowerCase();
        const tags = Array.isArray(p.tags) ? p.tags.join(" ").toLowerCase() : "";
        return name.includes(q) || desc.includes(q) || tags.includes(q);
      });

    const total = results.length;
    const offset = (page - 1) * limit;
    results = results.slice(offset, offset + limit);

    res.json({
      products: results,
      total,
      page,
      limit,
      hasMore: offset + limit < total,
    });
  } catch (error) {
    functions.logger.error("Error searching products", error);
    res.status(500).json({ error: "Erro ao buscar produtos" });
  }
});

/**
 * GET /api/marketplace/banners
 * Get homepage banners.
 */
router.get("/banners", async (req: Request, res: Response): Promise<void> => {
  try {
    const db = admin.firestore();
    const bannersSnap = await db
      .collection("banners")
      .where("isActive", "==", true)
      .orderBy("order", "asc")
      .limit(10)
      .get();

    const banners = bannersSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);

    res.json({ banners });
  } catch (error) {
    // Return empty banners if collection doesn't exist yet
    res.json({ banners: [] });
  }
});

// ============================================================================
// Services Marketplace
// ============================================================================

/**
 * GET /api/marketplace/services
 * List services with pagination and filters.
 */
router.get("/services", async (req: Request, res: Response): Promise<void> => {
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);
  const categoryId = req.query.categoryId ? String(req.query.categoryId) : undefined;
  const pricingType = req.query.pricingType ? String(req.query.pricingType) : undefined;
  const isRemote = req.query.isRemote === "true" ? true : undefined;
  const sortBy = req.query.sortBy ? String(req.query.sortBy) : "createdAt";

  try {
    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("services")
      .where("status", "==", "active");

    if (categoryId) {
      query = query.where("categoryId", "==", categoryId);
    }

    if (pricingType) {
      query = query.where("pricingType", "==", pricingType);
    }

    if (isRemote) {
      query = query.where("isRemote", "==", true);
    }

    // Sort
    if (sortBy === "price_asc") {
      query = query.orderBy("basePrice", "asc");
    } else if (sortBy === "rating") {
      query = query.orderBy("marketplaceStats.rating", "desc");
    } else if (sortBy === "popular") {
      query = query.orderBy("marketplaceStats.completedJobs", "desc");
    } else {
      query = query.orderBy("createdAt", "desc");
    }

    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    const offset = (page - 1) * limit;
    const servicesSnap = await query.offset(offset).limit(limit).get();

    // For marketplace listing, enrich with provider info
    const services = await Promise.all(
      servicesSnap.docs.map(async (doc) => {
        const data = doc.data();
        const tenantId = data.tenantId;

        // Get provider (tenant) info
        let provider = { id: tenantId, name: "", rating: 0, completedJobs: 0 };
        try {
          const tenantDoc = await db.collection("tenants").doc(tenantId).get();
          if (tenantDoc.exists) {
            const tenant = tenantDoc.data()!;
            provider = {
              id: tenantId,
              name: tenant.tradeName || "",
              rating: tenant.marketplaceStats?.averageRating || 0,
              completedJobs: tenant.marketplaceStats?.totalOrders || 0,
            };
          }
        } catch {
          // Ignore tenant lookup errors
        }

        return {
          id: data.id || doc.id,
          name: data.name,
          shortDescription: data.shortDescription || null,
          pricingType: data.pricingType,
          basePrice: data.basePrice,
          minPrice: data.minPrice || null,
          maxPrice: data.maxPrice || null,
          images: data.images || [],
          provider,
          serviceAreas: data.serviceAreas || [],
          isRemote: data.isRemote || false,
          rating: data.marketplaceStats?.rating || 0,
          reviewCount: data.marketplaceStats?.reviewCount || 0,
          certifications: data.certifications || [],
        };
      })
    );

    res.json({
      services,
      total,
      page,
      limit,
      nextCursor: offset + limit < total ? String(page + 1) : null,
    });
  } catch (error) {
    functions.logger.error("Error fetching services", error);
    res.status(500).json({ error: "Erro ao buscar servicos" });
  }
});

/**
 * GET /api/marketplace/services/featured
 * Get featured services.
 */
router.get("/services/featured", async (req: Request, res: Response): Promise<void> => {
  const limit = Math.min(parseInt(String(req.query.limit || "10")), 30);

  try {
    const db = admin.firestore();
    let servicesSnap = await db
      .collection("services")
      .where("status", "==", "active")
      .orderBy("marketplaceStats.completedJobs", "desc")
      .limit(limit)
      .get();

    // Fallback to recent if no stats
    if (servicesSnap.empty) {
      servicesSnap = await db
        .collection("services")
        .where("status", "==", "active")
        .orderBy("createdAt", "desc")
        .limit(limit)
        .get();
    }

    const services = await enrichServicesWithProvider(db, servicesSnap.docs);

    res.json({ services });
  } catch (error) {
    functions.logger.error("Error fetching featured services", error);
    res.status(500).json({ error: "Erro ao buscar servicos em destaque" });
  }
});

/**
 * GET /api/marketplace/services/recent
 * Get recently added services.
 */
router.get("/services/recent", async (req: Request, res: Response): Promise<void> => {
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);

  try {
    const db = admin.firestore();
    const servicesSnap = await db
      .collection("services")
      .where("status", "==", "active")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const services = await enrichServicesWithProvider(db, servicesSnap.docs);

    res.json({ services });
  } catch (error) {
    functions.logger.error("Error fetching recent services", error);
    res.status(500).json({ error: "Erro ao buscar servicos recentes" });
  }
});

/**
 * GET /api/marketplace/services/search
 * Search services by text query.
 */
router.get("/services/search", async (req: Request, res: Response): Promise<void> => {
  const q = req.query.q ? String(req.query.q).toLowerCase() : "";
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);

  if (!q) {
    res.json({ services: [], nextCursor: null });
    return;
  }

  try {
    const db = admin.firestore();
    const allSnap = await db
      .collection("services")
      .where("status", "==", "active")
      .orderBy("createdAt", "desc")
      .limit(500)
      .get();

    let results = allSnap.docs.filter((doc) => {
      const data = doc.data();
      const name = String(data.name || "").toLowerCase();
      const desc = String(data.description || "").toLowerCase();
      const tags = Array.isArray(data.tags) ? data.tags.join(" ").toLowerCase() : "";
      return name.includes(q) || desc.includes(q) || tags.includes(q);
    });

    const total = results.length;
    const offset = (page - 1) * limit;
    results = results.slice(offset, offset + limit);

    const services = await enrichServicesWithProvider(db, results);

    res.json({
      services,
      nextCursor: offset + limit < total ? String(page + 1) : null,
    });
  } catch (error) {
    functions.logger.error("Error searching services", error);
    res.status(500).json({ error: "Erro ao buscar servicos" });
  }
});

/**
 * GET /api/marketplace/services/:id
 * Get service details by ID.
 */
router.get("/services/:id", async (req: Request, res: Response): Promise<void> => {
  const serviceId = String(req.params.id);

  try {
    const db = admin.firestore();
    const serviceDoc = await db.collection("services").doc(serviceId).get();

    if (!serviceDoc.exists) {
      res.status(404).json({ error: "Servico nao encontrado" });
      return;
    }

    // Increment view count
    await db.collection("services").doc(serviceId).update({
      "marketplaceStats.views": admin.firestore.FieldValue.increment(1),
    });

    res.json({ id: serviceDoc.id, ...serializeTimestamps(serviceDoc.data()!) });
  } catch (error) {
    functions.logger.error("Error fetching service", error);
    res.status(500).json({ error: "Erro ao buscar servico" });
  }
});

/**
 * GET /api/marketplace/service-categories
 * Get service categories.
 */
router.get("/service-categories", async (req: Request, res: Response): Promise<void> => {
  try {
    const db = admin.firestore();
    const categoriesSnap = await db
      .collection("service_categories")
      .where("isActive", "==", true)
      .orderBy("order", "asc")
      .get();

    const categories = categoriesSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);

    res.json({ categories });
  } catch (error) {
    // Return empty if collection doesn't exist
    res.json({ categories: [] });
  }
});

// ============================================================================
// Tenant / Seller Profile (Public)
// ============================================================================

/**
 * GET /api/marketplace/tenants/:id
 * Public endpoint to fetch a seller's profile by tenantId.
 * Maps Firestore field names to what the Flutter TenantModel expects.
 */
router.get("/tenants/:id", async (req: Request, res: Response): Promise<void> => {
  const tenantId = String(req.params.id);
  if (!tenantId) {
    res.status(400).json({ error: "ID do vendedor obrigatório" });
    return;
  }

  try {
    const db = admin.firestore();
    const tenantDoc = await db.collection("tenants").doc(tenantId).get();

    if (!tenantDoc.exists) {
      res.status(404).json({ error: "Vendedor não encontrado" });
      return;
    }

    const data = tenantDoc.data()!;

    // Fetch owner user data to enrich fields missing from the tenant document
    const ownerUserId = (data.ownerUserId || data.ownerId || "") as string;
    let ownerData: admin.firestore.DocumentData | null = null;
    if (ownerUserId) {
      try {
        const ownerDoc = await db.collection("users").doc(ownerUserId).get();
        if (ownerDoc.exists) ownerData = ownerDoc.data()!;
      } catch {
        // Non-fatal — proceed without owner enrichment
      }
    }

    // Name: prefer tenant tradeName/name, fall back to owner's displayName
    const displayName =
      (data.tradeName || data.name || "").trim() ||
      (ownerData?.displayName as string | undefined || "").trim() ||
      "Vendedor";

    // Logo: prefer tenant logoURL, fall back to owner's photoURL
    const logoURL =
      data.logoURL || data.logoUrl || ownerData?.photoURL || null;

    // Normalize marketplace stats — stored as marketplaceStats by become-seller
    const stats = data.marketplaceStats || {};
    const marketplace = {
      isActive: true,
      rating: stats.averageRating || data.marketplace?.rating || 0,
      totalReviews: stats.totalReviews || data.marketplace?.totalReviews || 0,
      totalSales: stats.totalOrders || data.marketplace?.totalSales || 0,
      categories: data.categories || data.marketplace?.categories || [],
      deliveryOptions: data.deliveryOptions || data.marketplace?.deliveryOptions || [],
      paymentMethods: data.paymentMethods || data.marketplace?.paymentMethods || [],
    };

    // Normalize whatsapp — stored as either whatsapp or whatsappNumber
    const whatsappEnabled = data.whatsappEnabled || false;
    const whatsapp = whatsappEnabled
      ? (data.whatsapp || data.whatsappNumber || null)
      : null;

    res.json(serializeTimestamps({
      id: tenantDoc.id,
      type: data.type || "seller",
      name: displayName,
      tradeName: data.tradeName || null,
      logoURL,
      coverURL: data.coverURL || data.coverUrl || null,
      description: data.description || null,
      // Do not expose sensitive fields (email, phone, documentNumber)
      whatsapp,
      address: data.address || null,
      memberIds: data.memberIds || [],
      ownerUserId,
      isActive: data.isActive !== false,
      isVerified: data.isVerified || false,
      marketplace,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
    }));
  } catch (error) {
    functions.logger.error("Error fetching tenant by ID", { tenantId, error });
    res.status(500).json({ error: "Erro ao buscar perfil do vendedor" });
  }
});

// ============================================================================
// Reviews (Public Read)
// ============================================================================

/**
 * GET /api/marketplace/reviews
 * Fetch reviews for a product or seller.
 * Query params:
 *   productId — reviews for a specific product
 *   tenantId  — reviews for all products of a seller
 *   page, limit
 */
router.get("/reviews", async (req: Request, res: Response): Promise<void> => {
  const productId = req.query.productId ? String(req.query.productId) : undefined;
  const tenantId = req.query.tenantId ? String(req.query.tenantId) : undefined;
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "10")), 50);

  if (!productId && !tenantId) {
    res.status(400).json({ error: "productId ou tenantId são obrigatórios" });
    return;
  }

  try {
    const db = admin.firestore();
    const offset = (page - 1) * limit;

    let query: admin.firestore.Query = db.collection("reviews");

    if (productId) {
      query = query.where("productId", "==", productId);
    } else {
      query = query.where("tenantId", "==", tenantId!);
    }

    query = query.orderBy("createdAt", "desc");

    // Fetch limit+1 to detect hasMore, over-fetch to account for hidden reviews
    const snap = await query.offset(offset).limit(limit + 1).get();

    const allReviews = snap.docs.map((doc) => ({
      id: doc.id,
      ...serializeTimestamps(doc.data()),
    })) as Array<Record<string, unknown>>;

    // Filter hidden reviews in code (avoids complex composite index)
    const visibleReviews = allReviews.filter((r) => !r.isHidden);
    const hasMore = visibleReviews.length > limit;
    const reviews = visibleReviews.slice(0, limit);

    // Compute rating summary
    const ratingTotal = reviews.reduce((sum, r) => sum + Number(r.rating || 0), 0);
    const averageRating = reviews.length > 0 ? Math.round((ratingTotal / reviews.length) * 10) / 10 : 0;

    res.json({
      reviews,
      page,
      limit,
      hasMore,
      averageRating,
      totalReviews: reviews.length,
    });
  } catch (error) {
    functions.logger.error("Error fetching reviews", error);
    res.status(500).json({ error: "Erro ao buscar avaliações" });
  }
});

// ============================================================================
// Helpers
// ============================================================================

async function enrichServicesWithProvider(
  db: admin.firestore.Firestore,
  docs: admin.firestore.QueryDocumentSnapshot[]
): Promise<Record<string, unknown>[]> {
  // Batch-load unique tenant IDs
  const tenantIds = [...new Set(docs.map((doc) => doc.data().tenantId).filter(Boolean))];
  const tenantMap: Record<string, Record<string, unknown>> = {};

  for (const tid of tenantIds) {
    try {
      const tenantDoc = await db.collection("tenants").doc(tid).get();
      if (tenantDoc.exists) {
        const tenant = tenantDoc.data()!;
        tenantMap[tid] = {
          id: tid,
          name: tenant.tradeName || "",
          rating: tenant.marketplaceStats?.averageRating || 0,
          completedJobs: tenant.marketplaceStats?.totalOrders || 0,
        };
      }
    } catch {
      // Ignore
    }
  }

  return docs.map((doc) => {
    const data = doc.data();
    const tenantId = data.tenantId;
    const provider = tenantMap[tenantId] || { id: tenantId, name: "", rating: 0, completedJobs: 0 };

    return {
      id: data.id || doc.id,
      name: data.name,
      shortDescription: data.shortDescription || null,
      pricingType: data.pricingType,
      basePrice: data.basePrice,
      minPrice: data.minPrice || null,
      maxPrice: data.maxPrice || null,
      images: data.images || [],
      provider,
      serviceAreas: data.serviceAreas || [],
      isRemote: data.isRemote || false,
      rating: data.marketplaceStats?.rating || 0,
      reviewCount: data.marketplaceStats?.reviewCount || 0,
      certifications: data.certifications || [],
    };
  });
}

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
