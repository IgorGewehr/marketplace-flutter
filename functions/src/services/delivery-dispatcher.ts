import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { config } from "../config";

/**
 * Dispatch a delivery job to the external driver app via outbound webhook.
 * Called when a seller marks an order as "ready".
 *
 * If no outbound webhook URL is configured, logs a warning and returns silently.
 */
export async function dispatchDeliveryJob(
  db: admin.firestore.Firestore,
  orderId: string,
  orderData: admin.firestore.DocumentData,
): Promise<void> {
  // Check for webhook URL in config or Firestore
  let webhookUrl = config.delivery.outboundWebhookUrl;

  if (!webhookUrl) {
    try {
      const configDoc = await db.collection("config").doc("delivery").get();
      if (configDoc.exists) {
        webhookUrl = configDoc.data()?.outboundWebhookUrl || "";
      }
    } catch {
      // ignore
    }
  }

  if (!webhookUrl) {
    functions.logger.warn("No delivery outbound webhook URL configured — skipping dispatch", { orderId });
    return;
  }

  // Build payload
  const items = (orderData.items || []).map((item: Record<string, unknown>) => ({
    productId: item.productId,
    name: item.name,
    quantity: item.quantity,
    imageUrl: item.imageUrl || null,
  }));

  const payload = {
    orderId,
    orderNumber: orderData.orderNumber || null,
    seller: {
      tenantId: orderData.tenantId || null,
      address: null as Record<string, unknown> | null,
      phone: null as string | null,
      name: null as string | null,
    },
    buyer: {
      name: null as string | null,
      address: orderData.deliveryAddress || null,
      phone: null as string | null,
    },
    items,
    delivery: {
      tier: orderData.deliveryTier || null,
      type: orderData.deliveryType || null,
      sellerZoneId: orderData.sellerZoneId || null,
      buyerZoneId: orderData.buyerZoneId || null,
      zoneDistance: orderData.zoneDistance ?? null,
      fee: orderData.deliveryFee || 0,
      requiresVan: orderData.deliveryFeeBreakdown?.volumeSurcharge > 0,
      estimatedDeliveryDate: orderData.estimatedDeliveryDate || null,
    },
  };

  // Resolve seller info
  if (orderData.tenantId) {
    try {
      const tenantDoc = await db.collection("tenants").doc(orderData.tenantId).get();
      if (tenantDoc.exists) {
        const tenant = tenantDoc.data()!;
        payload.seller.name = tenant.name || null;
        payload.seller.address = tenant.address || null;
        payload.seller.phone = tenant.phone || null;
      }
    } catch {
      // best effort
    }
  }

  // Resolve buyer info
  if (orderData.buyerUserId) {
    try {
      const buyerDoc = await db.collection("users").doc(orderData.buyerUserId).get();
      if (buyerDoc.exists) {
        const buyer = buyerDoc.data()!;
        payload.buyer.name = buyer.displayName || buyer.name || null;
        payload.buyer.phone = buyer.phone || null;
      }
    } catch {
      // best effort
    }
  }

  // POST to webhook
  try {
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(config.delivery.webhookApiKey
          ? { "x-delivery-api-key": config.delivery.webhookApiKey }
          : {}),
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      functions.logger.error("Delivery webhook returned non-OK status", {
        orderId,
        status: response.status,
        statusText: response.statusText,
      });
    } else {
      functions.logger.info("Delivery job dispatched successfully", { orderId });
    }
  } catch (fetchErr) {
    functions.logger.error("Failed to call delivery webhook", { orderId, error: String(fetchErr) });
  }

  // Mark order as dispatched
  const now = admin.firestore.Timestamp.now();
  await db.collection("orders").doc(orderId).update({
    deliveryDispatchedAt: now,
    updatedAt: now,
  });
}
