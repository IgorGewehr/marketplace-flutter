import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";

const router = Router();

// ============================================================================
// Seller Profile
// ============================================================================

/**
 * GET /api/seller/profile
 * Returns the seller's public profile including WhatsApp config.
 */
router.get("/profile", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const tenantDoc = await admin.firestore().collection("tenants").doc(tenantId).get();
    if (!tenantDoc.exists) {
      res.status(404).json({ error: "Perfil não encontrado" });
      return;
    }

    const data = tenantDoc.data()!;
    res.json({
      tenantId,
      name: data.name || "",
      description: data.description || "",
      whatsappNumber: data.whatsappNumber || null,
      whatsappEnabled: data.whatsappEnabled || false,
      logoUrl: data.logoURL || null,
      coverUrl: data.coverURL || null,
      categories: data.categories || [],
      address: data.address || null,
      marketplaceStats: data.marketplaceStats || null,
      mpConnection: data.mpConnection
        ? { isConnected: data.mpConnection.isConnected || false }
        : { isConnected: false },
    });
  } catch (error) {
    functions.logger.error("Error fetching seller profile", error);
    res.status(500).json({ error: "Erro ao buscar perfil" });
  }
});

/**
 * PATCH /api/seller/profile
 * Updates seller profile fields including WhatsApp config.
 *
 * Body: { whatsappNumber?, whatsappEnabled?, description?, name? }
 */
router.patch("/profile", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const { whatsappNumber, whatsappEnabled, description, name, logoUrl, coverUrl } = req.body;

    // Validate WhatsApp number format if provided and non-empty
    if (whatsappNumber !== undefined && whatsappNumber !== null && whatsappNumber !== "") {
      const cleaned = String(whatsappNumber).replace(/\D/g, "");
      if (cleaned.length < 10 || cleaned.length > 13) {
        res.status(400).json({ error: "Número de WhatsApp inválido. Use formato: (11) 99999-9999" });
        return;
      }
    }

    // Validate logo/cover URLs if provided
    if (logoUrl !== undefined && logoUrl !== null && logoUrl !== "") {
      if (typeof logoUrl !== "string" || !logoUrl.startsWith("https://")) {
        res.status(400).json({ error: "URL de logo inválida" });
        return;
      }
    }
    if (coverUrl !== undefined && coverUrl !== null && coverUrl !== "") {
      if (typeof coverUrl !== "string" || !coverUrl.startsWith("https://")) {
        res.status(400).json({ error: "URL de capa inválida" });
        return;
      }
    }

    const updateData: Record<string, unknown> = {
      updatedAt: admin.firestore.Timestamp.now(),
    };

    if (whatsappNumber !== undefined) updateData.whatsappNumber = whatsappNumber || null;
    if (whatsappEnabled !== undefined) updateData.whatsappEnabled = Boolean(whatsappEnabled);
    if (description !== undefined) updateData.description = description;
    if (name !== undefined && String(name).trim()) updateData.name = String(name).trim();
    // logoURL / coverURL — stored with capital URL to match TenantModel convention
    if (logoUrl !== undefined) updateData.logoURL = logoUrl || null;
    if (coverUrl !== undefined) updateData.coverURL = coverUrl || null;

    await admin.firestore().collection("tenants").doc(tenantId).update(updateData);

    const updatedDoc = await admin.firestore().collection("tenants").doc(tenantId).get();
    const data = updatedDoc.data()!;

    functions.logger.info("Seller profile updated", { uid, tenantId, fields: Object.keys(updateData) });

    res.json({
      tenantId,
      name: data.name || "",
      description: data.description || "",
      whatsappNumber: data.whatsappNumber || null,
      whatsappEnabled: data.whatsappEnabled || false,
      logoUrl: data.logoURL || null,
      coverUrl: data.coverURL || null,
      categories: data.categories || [],
      address: data.address || null,
      marketplaceStats: data.marketplaceStats || null,
      mpConnection: data.mpConnection
        ? { isConnected: data.mpConnection.isConnected || false }
        : { isConnected: false },
    });
  } catch (error) {
    functions.logger.error("Error updating seller profile", error);
    res.status(500).json({ error: "Erro ao atualizar perfil" });
  }
});

// ============================================================================
// Seller Summary / Analytics
// ============================================================================

/**
 * GET /api/seller/summary
 * Returns key dashboard metrics for the current month.
 *
 * Response:
 *   month.totalOrders      — total orders placed this month
 *   month.revenue          — gross revenue from paid orders (rounded to 2 dp)
 *   month.netRevenue       — seller net revenue after marketplace fee (rounded to 2 dp)
 *   month.ordersByStatus   — map of status → count
 *   newOrdersCount         — orders in pending or confirmed state (this month)
 */
router.get("/summary", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const monthOrdersSnap = await db
      .collection("orders")
      .where("tenantId", "==", tenantId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(startOfMonth))
      .get();

    let monthRevenue = 0;
    let monthNetRevenue = 0;
    const ordersByStatus: Record<string, number> = {};

    for (const doc of monthOrdersSnap.docs) {
      const data = doc.data();
      ordersByStatus[data.status] = (ordersByStatus[data.status] || 0) + 1;
      if (data.paymentStatus === "paid") {
        monthRevenue += data.total || 0;
        monthNetRevenue += data.paymentSplit?.sellerAmount || 0;
      }
    }

    const newOrdersCount =
      (ordersByStatus["pending"] || 0) + (ordersByStatus["confirmed"] || 0);

    res.json({
      month: {
        totalOrders: monthOrdersSnap.size,
        revenue: Math.round(monthRevenue * 100) / 100,
        netRevenue: Math.round(monthNetRevenue * 100) / 100,
        ordersByStatus,
      },
      newOrdersCount,
    });
  } catch (error) {
    functions.logger.error("Error fetching seller summary", error);
    res.status(500).json({ error: "Erro ao buscar resumo" });
  }
});

export default router;
