import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";

const router = Router();

// ============================================================================
// Seller Service Management (CRUD)
// ============================================================================

/**
 * GET /api/services
 * List seller's own services.
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
      .collection("services")
      .where("tenantId", "==", tenantId)
      .orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    const offset = (page - 1) * limit;
    const servicesSnap = await query.offset(offset).limit(limit).get();

    const services = servicesSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }));

    res.json({
      services,
      total,
      page,
      limit,
      nextCursor: offset + limit < total ? String(page + 1) : null,
    });
  } catch (error) {
    functions.logger.error("Error fetching seller services", error);
    res.status(500).json({ error: "Erro ao buscar servicos" });
  }
});

/**
 * POST /api/services
 * Create a new service.
 *
 * Body: Service fields
 */
router.post("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  const {
    name, description, shortDescription, categoryId, subcategoryId,
    tags, images, portfolioImages, pricingType, basePrice, minPrice, maxPrice,
    isAvailable, availableDays, serviceHours, serviceAreas,
    isRemote, isOnSite, duration, requirements, includes, excludes,
    certifications, experience, acceptsQuote, instantBooking,
  } = req.body;

  if (!name || basePrice === undefined || basePrice === null) {
    res.status(400).json({ error: "Nome e preco base sao obrigatorios" });
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
    const serviceId = uuidv4();

    const serviceData: Record<string, unknown> = {
      id: serviceId,
      tenantId,
      name,
      description: description || "",
      shortDescription: shortDescription || null,
      categoryId: categoryId || "",
      subcategoryId: subcategoryId || null,
      tags: tags || [],
      images: images || [],
      portfolioImages: portfolioImages || [],
      pricingType: pricingType || "fixed",
      basePrice: parseFloat(basePrice) || 0,
      minPrice: minPrice ? parseFloat(minPrice) : null,
      maxPrice: maxPrice ? parseFloat(maxPrice) : null,
      isAvailable: isAvailable ?? true,
      availableDays: availableDays || [],
      serviceHours: serviceHours || null,
      serviceAreas: serviceAreas || [],
      isRemote: isRemote ?? false,
      isOnSite: isOnSite ?? true,
      duration: duration || null,
      requirements: requirements || [],
      includes: includes || [],
      excludes: excludes || [],
      certifications: certifications || [],
      experience: experience || null,
      status: "active",
      acceptsQuote: acceptsQuote ?? true,
      instantBooking: instantBooking ?? false,
      marketplaceStats: {
        views: 0,
        favorites: 0,
        completedJobs: 0,
        rating: 0,
        reviewCount: 0,
      },
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("services").doc(serviceId).set(serviceData);

    functions.logger.info("Service created", { uid, serviceId, tenantId });

    res.status(201).json(serializeTimestamps(serviceData));
  } catch (error) {
    functions.logger.error("Error creating service", error);
    res.status(500).json({ error: "Erro ao criar servico" });
  }
});

/**
 * PATCH /api/services/:id
 * Update an existing service.
 */
router.patch("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const serviceId = String(req.params.id);

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const serviceRef = db.collection("services").doc(serviceId);
    const serviceDoc = await serviceRef.get();

    if (!serviceDoc.exists) {
      res.status(404).json({ error: "Servico nao encontrado" });
      return;
    }

    if (serviceDoc.data()!.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const updateData: Record<string, unknown> = { updatedAt: now };

    const allowedFields = [
      "name", "description", "shortDescription", "categoryId", "subcategoryId",
      "tags", "images", "portfolioImages", "pricingType", "basePrice", "minPrice", "maxPrice",
      "isAvailable", "availableDays", "serviceHours", "serviceAreas",
      "isRemote", "isOnSite", "duration", "requirements", "includes", "excludes",
      "certifications", "experience", "status", "acceptsQuote", "instantBooking",
    ];

    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        let value = req.body[field];
        if (field === "basePrice" || field === "minPrice" || field === "maxPrice") {
          value = value !== null ? parseFloat(value) : null;
        }
        updateData[field] = value;
      }
    }

    await serviceRef.update(updateData);

    const updatedDoc = await serviceRef.get();
    res.json(serializeTimestamps(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error updating service", error);
    res.status(500).json({ error: "Erro ao atualizar servico" });
  }
});

/**
 * DELETE /api/services/:id
 * Delete a service (soft delete).
 */
router.delete("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const serviceId = String(req.params.id);

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const serviceRef = db.collection("services").doc(serviceId);
    const serviceDoc = await serviceRef.get();

    if (!serviceDoc.exists) {
      res.status(404).json({ error: "Servico nao encontrado" });
      return;
    }

    if (serviceDoc.data()!.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    await serviceRef.update({
      status: "inactive",
      updatedAt: admin.firestore.Timestamp.now(),
    });

    functions.logger.info("Service deleted", { uid, serviceId, tenantId });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error deleting service", error);
    res.status(500).json({ error: "Erro ao excluir servico" });
  }
});

/**
 * DELETE /api/services/:serviceId/images/:imageId
 * Delete a specific image from a service.
 */
router.delete("/:serviceId/images/:imageId", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const serviceId = String(req.params.serviceId);
  const imageId = String(req.params.imageId);
  const category = req.query.category ? String(req.query.category) : "profile";

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const serviceRef = db.collection("services").doc(serviceId);
    const serviceDoc = await serviceRef.get();

    if (!serviceDoc.exists) {
      res.status(404).json({ error: "Servico nao encontrado" });
      return;
    }

    if (serviceDoc.data()!.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    const data = serviceDoc.data()!;
    const field = category === "portfolio" ? "portfolioImages" : "images";
    const images = (data[field] || []) as Record<string, unknown>[];
    const filtered = images.filter((img) => img.id !== imageId);

    await serviceRef.update({
      [field]: filtered,
      updatedAt: admin.firestore.Timestamp.now(),
    });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error deleting service image", error);
    res.status(500).json({ error: "Erro ao excluir imagem" });
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
