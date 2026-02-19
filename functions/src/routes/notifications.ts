import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();

// ============================================================================
// Notification Endpoints
// ============================================================================

/**
 * GET /api/notifications
 * List notifications for the authenticated user.
 *
 * Query params: page, limit, unreadOnly
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);
  const unreadOnly = req.query.unreadOnly === "true";

  try {
    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("notifications")
      .where("userId", "==", uid)
      .orderBy("createdAt", "desc");

    if (unreadOnly) {
      query = query.where("isRead", "==", false);
    }

    // Get total count
    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    // Get unread count
    const unreadSnap = await db
      .collection("notifications")
      .where("userId", "==", uid)
      .where("isRead", "==", false)
      .count()
      .get();
    const unreadCount = unreadSnap.data().count;

    // Paginate
    const offset = (page - 1) * limit;
    const notificationsSnap = await query.offset(offset).limit(limit).get();

    const notifications = notificationsSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }));

    res.json({
      notifications,
      total,
      page,
      limit,
      hasMore: offset + limit < total,
      unreadCount,
    });
  } catch (error) {
    functions.logger.error("Error fetching notifications", error);
    res.status(500).json({ error: "Erro ao buscar notificacoes" });
  }
});

/**
 * PATCH /api/notifications/:id
 * Mark a notification as read.
 */
router.patch("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const notificationId = String(req.params.id);

  try {
    const db = admin.firestore();
    const notifRef = db.collection("notifications").doc(notificationId);
    const notifDoc = await notifRef.get();

    if (!notifDoc.exists) {
      res.status(404).json({ error: "Notificacao nao encontrada" });
      return;
    }

    if (notifDoc.data()!.userId !== uid) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    await notifRef.update({
      isRead: true,
      readAt: now,
      updatedAt: now,
    });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error marking notification read", error);
    res.status(500).json({ error: "Erro ao marcar notificacao" });
  }
});

/**
 * POST /api/notifications/mark-all-read
 * Mark all notifications as read.
 */
router.post("/mark-all-read", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const unreadSnap = await db
      .collection("notifications")
      .where("userId", "==", uid)
      .where("isRead", "==", false)
      .get();

    if (unreadSnap.empty) {
      res.json({ success: true, updated: 0 });
      return;
    }

    // Batch update (Firestore limit: 500 per batch)
    const batches: admin.firestore.WriteBatch[] = [];
    let currentBatch = db.batch();
    let batchCount = 0;

    for (const doc of unreadSnap.docs) {
      currentBatch.update(doc.ref, {
        isRead: true,
        readAt: now,
        updatedAt: now,
      });
      batchCount++;

      if (batchCount === 500) {
        batches.push(currentBatch);
        currentBatch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      batches.push(currentBatch);
    }

    await Promise.all(batches.map((b) => b.commit()));

    res.json({ success: true, updated: unreadSnap.size });
  } catch (error) {
    functions.logger.error("Error marking all notifications read", error);
    res.status(500).json({ error: "Erro ao marcar notificacoes" });
  }
});

/**
 * DELETE /api/notifications/:id
 * Delete a single notification.
 */
router.delete("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const notificationId = String(req.params.id);

  try {
    const db = admin.firestore();
    const notifRef = db.collection("notifications").doc(notificationId);
    const notifDoc = await notifRef.get();

    if (!notifDoc.exists) {
      res.status(404).json({ error: "Notificacao nao encontrada" });
      return;
    }

    if (notifDoc.data()!.userId !== uid) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    await notifRef.delete();

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error deleting notification", error);
    res.status(500).json({ error: "Erro ao excluir notificacao" });
  }
});

/**
 * DELETE /api/notifications
 * Delete all notifications for the user.
 */
router.delete("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const db = admin.firestore();
    const allSnap = await db
      .collection("notifications")
      .where("userId", "==", uid)
      .get();

    if (allSnap.empty) {
      res.json({ success: true, deleted: 0 });
      return;
    }

    const batches: admin.firestore.WriteBatch[] = [];
    let currentBatch = db.batch();
    let batchCount = 0;

    for (const doc of allSnap.docs) {
      currentBatch.delete(doc.ref);
      batchCount++;

      if (batchCount === 500) {
        batches.push(currentBatch);
        currentBatch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      batches.push(currentBatch);
    }

    await Promise.all(batches.map((b) => b.commit()));

    res.json({ success: true, deleted: allSnap.size });
  } catch (error) {
    functions.logger.error("Error deleting all notifications", error);
    res.status(500).json({ error: "Erro ao excluir notificacoes" });
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
