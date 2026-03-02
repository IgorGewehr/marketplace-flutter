import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();

// ============================================================================
// Distance-based price multipliers
// ============================================================================
const DISTANCE_MULTIPLIERS: Record<number, { multiplier: number; estimate: string }> = {
  0: { multiplier: 0.5, estimate: "Estimativa: 2-4 dias úteis" },
  1: { multiplier: 0.7, estimate: "Estimativa: 3-5 dias úteis" },
  2: { multiplier: 0.85, estimate: "Estimativa: 5-8 dias úteis" },
};
// Distance 3+ uses the default
const DEFAULT_DISTANCE = { multiplier: 1.0, estimate: "Estimativa: 5-8 dias úteis" };

const TIER_LABELS: Record<string, string> = {
  scheduled: "Entrega padrão",
  seller_arranges: "Combinar com vendedor",
};

// Tier multipliers on top of distance-adjusted base
const TIER_MULTIPLIERS: Record<string, number> = {
  scheduled: 1.0,
};

// Weight surcharge: R$1.00 per kg over 5kg
const WEIGHT_FREE_KG = 5;
const WEIGHT_SURCHARGE_PER_KG = 1.0;

// Volume surcharge if requires van
const VOLUME_SURCHARGE = 2.0;

// Global free delivery minimum — applies to ALL zones
const GLOBAL_FREE_DELIVERY_MINIMUM = 150;

// ============================================================================
// Types
// ============================================================================

interface FreightItem {
  weight?: number;
  dimensions?: { width: number; height: number; length: number };
  quantity: number;
  shippingPolicy?: string;
}

interface FreightOption {
  zoneId: string;
  zoneName: string;
  tier: string;
  tierLabel: string;
  price: number;
  estimatedDelivery: string;
  estimatedDeliveryDate: string | null;
  requiresVan: boolean;
  available: boolean;
  unavailableReason?: string;
  breakdown: {
    basePrice: number;
    weightSurcharge: number;
    volumeSurcharge: number;
    tierPremium: number;
    freeDeliveryDiscount: number;
    pickupDiscount: number;
  };
  pickupPointId?: string;
  pickupPointName?: string;
  pickupPointAddress?: string;
  isFreeDelivery: boolean;
  freeDeliveryThreshold?: number;
  amountToFreeDelivery?: number;
  sellerZoneId?: string;
  sellerZoneName?: string;
  zoneDistance?: number;
}

interface FreightCalculationResult {
  options: FreightOption[];
  freeDeliveryMessage?: string;
  sellerZoneId?: string;
  sellerZoneName?: string;
  buyerZoneId?: string;
  zoneDistance?: number;
  hasMixedCart?: boolean;
  pickupOnlyCount?: number;
}

// ============================================================================
// Public: GET /zones
// ============================================================================

router.get("/zones", async (_req: Request, res: Response): Promise<void> => {
  try {
    const db = admin.firestore();
    const zonesSnap = await db
      .collection("delivery_zones")
      .where("isActive", "==", true)
      .orderBy("sortOrder", "asc")
      .get();

    const zones = zonesSnap.docs.map((doc) => ({
      id: doc.id,
      ...serializeTimestamps(doc.data()),
    }));

    res.json({ zones });
  } catch (error) {
    functions.logger.error("Error fetching delivery zones", error);
    res.status(500).json({ error: "Erro ao buscar zonas de entrega" });
  }
});

// ============================================================================
// Public: GET /pickup-points
// ============================================================================

router.get("/pickup-points", async (req: Request, res: Response): Promise<void> => {
  try {
    const db = admin.firestore();
    const zoneId = req.query.zoneId ? String(req.query.zoneId) : undefined;

    let query: admin.firestore.Query = db
      .collection("pickup_points")
      .where("isActive", "==", true);

    if (zoneId) {
      query = query.where("zoneId", "==", zoneId);
    }

    const pointsSnap = await query.get();
    const points = pointsSnap.docs.map((doc) => ({
      id: doc.id,
      ...serializeTimestamps(doc.data()),
    }));

    res.json({ pickupPoints: points });
  } catch (error) {
    functions.logger.error("Error fetching pickup points", error);
    res.status(500).json({ error: "Erro ao buscar pontos de retirada" });
  }
});

// ============================================================================
// Authenticated: POST /calculate
// ============================================================================

router.post("/calculate", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  if (!authReq.uid) {
    res.status(401).json({ error: "Não autenticado" });
    return;
  }

  const { zipCode, city, subtotal, items, tenantId } = req.body;

  if (!items || !Array.isArray(items) || items.length === 0) {
    res.status(400).json({ error: "Itens são obrigatórios" });
    return;
  }

  try {
    const result = await calculateFreightForItems({
      zipCode: zipCode || "",
      city: city || "",
      subtotal: subtotal || 0,
      items,
      tenantId: tenantId || "",
    });

    res.json(result);
  } catch (error) {
    functions.logger.error("Error calculating freight", error);
    res.status(500).json({ error: "Erro ao calcular frete" });
  }
});

// ============================================================================
// Exported calculation function (reused by payments.ts)
// ============================================================================

export async function calculateFreightForItems(params: {
  zipCode: string;
  city: string;
  subtotal: number;
  items: FreightItem[];
  tenantId?: string;
}): Promise<FreightCalculationResult> {
  const { zipCode, city, subtotal, items, tenantId } = params;
  const db = admin.firestore();

  // 1. Filter items: only delivery items count for freight
  const deliveryItems = items.filter((item) => item.shippingPolicy !== "pickup_only");
  const pickupOnlyCount = items.length - deliveryItems.length;
  const hasMixedCart = pickupOnlyCount > 0 && deliveryItems.length > 0;
  const allPickupOnly = deliveryItems.length === 0;

  // If all items are pickup_only, no freight needed
  if (allPickupOnly) {
    return {
      options: [],
      hasMixedCart: false,
      pickupOnlyCount,
    };
  }

  // 2. Resolve seller zone from tenantId
  let sellerZone: { id: string; data: admin.firestore.DocumentData } | null = null;
  let sellerCity = "";
  if (tenantId) {
    const tenantDoc = await db.collection("tenants").doc(tenantId).get();
    if (tenantDoc.exists) {
      const tenantData = tenantDoc.data()!;
      const sellerAddress = tenantData.address || {};
      const sellerZip = sellerAddress.zipCode || "";
      sellerCity = (sellerAddress.city || "").toLowerCase().trim();
      sellerZone = await resolveZone(db, sellerZip, sellerAddress.city || "");
    }
  }
  // Fallback to zone_0 if seller zone not resolved
  if (!sellerZone) {
    const fallbackDoc = await db.collection("delivery_zones").doc("zone_0").get();
    if (fallbackDoc.exists) {
      sellerZone = { id: "zone_0", data: fallbackDoc.data()! };
    }
  }

  const sellerZoneId = sellerZone?.id || "zone_0";
  const sellerZoneName = sellerZone?.data?.name || "Concórdia Centro";

  // 3. Resolve buyer zone from zipCode/city
  const buyerZone = await resolveZone(db, zipCode, city);

  // If buyer is out of zone, return seller_arranges option
  if (!buyerZone) {
    return {
      options: [{
        zoneId: "out_of_zone",
        zoneName: "Fora da área de entrega",
        tier: "seller_arranges",
        tierLabel: TIER_LABELS.seller_arranges,
        price: 0,
        estimatedDelivery: "A combinar",
        estimatedDeliveryDate: null,
        requiresVan: false,
        available: true,
        breakdown: {
          basePrice: 0,
          weightSurcharge: 0,
          volumeSurcharge: 0,
          tierPremium: 0,
          freeDeliveryDiscount: 0,
          pickupDiscount: 0,
        },
        isFreeDelivery: false,
        sellerZoneId,
        sellerZoneName,
        zoneDistance: -1,
      }],
      sellerZoneId,
      sellerZoneName,
      buyerZoneId: "out_of_zone",
      zoneDistance: -1,
      hasMixedCart,
      pickupOnlyCount,
    };
  }

  const buyerZoneId = buyerZone.id;
  const buyerZoneData = buyerZone.data;

  // 4. Compute zone distance via BFS
  const allZonesSnap = await db
    .collection("delivery_zones")
    .where("isActive", "==", true)
    .get();

  const adjacencyMap = new Map<string, string[]>();
  for (const doc of allZonesSnap.docs) {
    const data = doc.data();
    adjacencyMap.set(doc.id, data.adjacentZones || []);
  }

  const zoneDistance = computeZoneDistance(sellerZoneId, buyerZoneId, adjacencyMap);

  // 4b. Concórdia-to-Concórdia: always free delivery
  const buyerCityLower = city.toLowerCase().trim();
  const isConcordiaToConcordia =
    buyerCityLower === "concórdia" && sellerCity === "concórdia";

  if (isConcordiaToConcordia) {
    const estimatedDelivery = getEstimatedDeliveryLabel("scheduled", 0);
    const estimatedDate = calculateEstimatedDeliveryDate("scheduled", 0);

    const freeOptions: FreightOption[] = [
      {
        zoneId: buyerZoneId,
        zoneName: buyerZoneData.name || "Concórdia",
        tier: "scheduled",
        tierLabel: TIER_LABELS.scheduled,
        price: 0,
        estimatedDelivery,
        estimatedDeliveryDate: estimatedDate ? estimatedDate.toISOString() : null,
        requiresVan: false,
        available: true,
        breakdown: {
          basePrice: 0,
          weightSurcharge: 0,
          volumeSurcharge: 0,
          tierPremium: 0,
          freeDeliveryDiscount: 0,
          pickupDiscount: 0,
        },
        isFreeDelivery: true,
        sellerZoneId,
        sellerZoneName,
        zoneDistance: 0,
      },
      {
        zoneId: sellerZoneId,
        zoneName: sellerZoneName,
        tier: "pickup_point",
        tierLabel: "Retirar na loja",
        price: 0,
        estimatedDelivery: "Disponível após confirmação",
        estimatedDeliveryDate: null,
        requiresVan: false,
        available: true,
        breakdown: {
          basePrice: 0,
          weightSurcharge: 0,
          volumeSurcharge: 0,
          tierPremium: 0,
          freeDeliveryDiscount: 0,
          pickupDiscount: 0,
        },
        isFreeDelivery: true,
        sellerZoneId,
        sellerZoneName,
        zoneDistance: 0,
      },
    ];

    return {
      options: freeOptions,
      freeDeliveryMessage: "Frete grátis para entregas em Concórdia!",
      sellerZoneId,
      sellerZoneName,
      buyerZoneId,
      zoneDistance: 0,
      hasMixedCart,
      pickupOnlyCount,
    };
  }

  // 5. Calculate total weight and volume from delivery items only
  let totalWeight = 0;
  let requiresVan = false;

  for (const item of deliveryItems) {
    const qty = item.quantity || 1;
    totalWeight += (item.weight || 0) * qty;

    if (item.dimensions) {
      const { width, height, length } = item.dimensions;
      if (width > 40 || height > 30 || length > 30) {
        requiresVan = true;
      }
    }
  }

  // 6. Calculate surcharges
  const weightSurcharge = Math.max(0, (totalWeight - WEIGHT_FREE_KG)) * WEIGHT_SURCHARGE_PER_KG;
  const volumeSurcharge = requiresVan ? VOLUME_SURCHARGE : 0;

  // 7. Get distance-adjusted base price
  const distanceInfo = DISTANCE_MULTIPLIERS[zoneDistance] || DEFAULT_DISTANCE;
  const buyerBasePrice = buyerZoneData.basePrice || 0;
  const adjustedBase = Math.round(buyerBasePrice * distanceInfo.multiplier * 100) / 100;

  // 8. Only one tier: scheduled (entrega padrão)
  const tiers: string[] = ["scheduled"];

  // 9. Build freight options
  const options: FreightOption[] = [];
  const freeDeliveryMin = buyerZoneData.freeDeliveryMinimum || null;

  for (const tier of tiers) {
    const tierMultiplier = TIER_MULTIPLIERS[tier] || 1.0;
    const tierPremium = 0;
    const tierBase = Math.round(adjustedBase * tierMultiplier * 100) / 100;

    const rawPrice = tierBase + weightSurcharge + volumeSurcharge + tierPremium;

    // Free delivery discount
    let freeDeliveryDiscount = 0;
    let isFreeDelivery = false;
    let amountToFreeDelivery: number | undefined;

    // Use the lower of global or zone-specific minimum (if zone has one)
    const effectiveMinimum = freeDeliveryMin
      ? Math.min(GLOBAL_FREE_DELIVERY_MINIMUM, freeDeliveryMin)
      : GLOBAL_FREE_DELIVERY_MINIMUM;

    if (subtotal >= effectiveMinimum) {
      freeDeliveryDiscount = tierBase;
      isFreeDelivery = true;
    } else {
      amountToFreeDelivery = Math.round((effectiveMinimum - subtotal) * 100) / 100;
      if (amountToFreeDelivery < 0) amountToFreeDelivery = undefined;
    }

    const finalPrice = Math.max(0, Math.round((rawPrice - freeDeliveryDiscount) * 100) / 100);

    const available = true;
    const unavailableReason: string | undefined = undefined;

    const estimatedDelivery = getEstimatedDeliveryLabel(tier, zoneDistance);
    const estimatedDate = calculateEstimatedDeliveryDate(tier, zoneDistance);

    options.push({
      zoneId: buyerZoneId,
      zoneName: buyerZoneData.name || "",
      tier,
      tierLabel: TIER_LABELS[tier] || tier,
      price: finalPrice,
      estimatedDelivery,
      estimatedDeliveryDate: estimatedDate ? estimatedDate.toISOString() : null,
      requiresVan,
      available,
      unavailableReason,
      breakdown: {
        basePrice: tierBase,
        weightSurcharge,
        volumeSurcharge,
        tierPremium,
        freeDeliveryDiscount,
        pickupDiscount: 0,
      },
      isFreeDelivery,
      freeDeliveryThreshold: effectiveMinimum,
      amountToFreeDelivery,
      sellerZoneId,
      sellerZoneName,
      zoneDistance,
    });
  }

  // Always add free store pickup option
  options.push({
    zoneId: sellerZoneId,
    zoneName: sellerZoneName,
    tier: "pickup_point",
    tierLabel: "Retirar na loja",
    price: 0,
    estimatedDelivery: "Disponível após confirmação",
    estimatedDeliveryDate: null,
    requiresVan: false,
    available: true,
    breakdown: {
      basePrice: 0,
      weightSurcharge: 0,
      volumeSurcharge: 0,
      tierPremium: 0,
      freeDeliveryDiscount: 0,
      pickupDiscount: 0,
    },
    isFreeDelivery: true,
    sellerZoneId,
    sellerZoneName,
    zoneDistance: 0,
  });

  // Free delivery message
  let freeDeliveryMessage: string | undefined;
  const globalEffectiveMin = freeDeliveryMin
    ? Math.min(GLOBAL_FREE_DELIVERY_MINIMUM, freeDeliveryMin)
    : GLOBAL_FREE_DELIVERY_MINIMUM;

  if (subtotal < globalEffectiveMin) {
    const remaining = Math.round((globalEffectiveMin - subtotal) * 100) / 100;
    freeDeliveryMessage = `Adicione R$ ${remaining.toFixed(2)} para frete grátis`;
  } else {
    freeDeliveryMessage = "Frete grátis nesta entrega! 🎉";
  }

  return {
    options,
    freeDeliveryMessage,
    sellerZoneId,
    sellerZoneName,
    buyerZoneId,
    zoneDistance,
    hasMixedCart,
    pickupOnlyCount,
  };
}

// ============================================================================
// BFS zone distance
// ============================================================================

function computeZoneDistance(
  fromZone: string,
  toZone: string,
  adjacencyMap: Map<string, string[]>,
): number {
  if (fromZone === toZone) return 0;

  const visited = new Set<string>();
  const queue: { zoneId: string; distance: number }[] = [{ zoneId: fromZone, distance: 0 }];
  visited.add(fromZone);

  while (queue.length > 0) {
    const { zoneId, distance } = queue.shift()!;
    const neighbors = adjacencyMap.get(zoneId) || [];

    for (const neighbor of neighbors) {
      if (neighbor === toZone) return distance + 1;
      if (!visited.has(neighbor)) {
        visited.add(neighbor);
        queue.push({ zoneId: neighbor, distance: distance + 1 });
      }
    }
  }

  // Zones not connected — treat as maximum distance
  return 99;
}

// ============================================================================
// Helpers
// ============================================================================

async function resolveZone(
  db: admin.firestore.Firestore,
  zipCode: string,
  city: string,
): Promise<{ id: string; data: admin.firestore.DocumentData } | null> {
  // Try matching by zipCode prefix
  const cleanZip = zipCode.replace(/\D/g, "");
  if (cleanZip.length >= 5) {
    const prefix = cleanZip.substring(0, 5);
    const zipSnap = await db
      .collection("delivery_zones")
      .where("isActive", "==", true)
      .where("zipPrefixes", "array-contains", prefix)
      .limit(1)
      .get();

    if (!zipSnap.empty) {
      const doc = zipSnap.docs[0];
      return { id: doc.id, data: doc.data() };
    }
  }

  // Try matching by city name (case-insensitive via lowercase field)
  if (city) {
    const cityLower = city.toLowerCase().trim();
    const citySnap = await db
      .collection("delivery_zones")
      .where("isActive", "==", true)
      .where("citiesLowercase", "array-contains", cityLower)
      .limit(1)
      .get();

    if (!citySnap.empty) {
      const doc = citySnap.docs[0];
      return { id: doc.id, data: doc.data() };
    }
  }

  return null;
}

function getEstimatedDeliveryLabel(tier: string, zoneDistance: number): string {
  switch (tier) {
  case "scheduled": {
    const distanceInfo = DISTANCE_MULTIPLIERS[zoneDistance] || DEFAULT_DISTANCE;
    return distanceInfo.estimate;
  }
  case "seller_arranges":
    return "A combinar";
  default: {
    const info = DISTANCE_MULTIPLIERS[zoneDistance] || DEFAULT_DISTANCE;
    return info.estimate;
  }
  }
}

function calculateEstimatedDeliveryDate(
  tier: string,
  zoneDistance: number,
): Date | null {
  if (tier === "seller_arranges") return null;

  const now = new Date();
  const brtOffset = -3;
  const brtNow = new Date(now.getTime() + brtOffset * 60 * 60 * 1000);

  // Estimated upper bound — not a promise
  const daysToAdd = zoneDistance <= 0 ? 4 : zoneDistance <= 1 ? 5 : 8;
  const estimated = new Date(brtNow);
  estimated.setDate(estimated.getDate() + daysToAdd);
  estimated.setHours(18, 0, 0, 0);
  return estimated;
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
