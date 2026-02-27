import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";

const router = Router();

// ============================================================================
// Chat Endpoints
// ============================================================================

/**
 * GET /api/chats
 * Get all chats for the current user.
 * Query params:
 *   orderId (optional) - filter by order ID
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const orderId = req.query.orderId ? String(req.query.orderId) : undefined;

  try {
    const db = admin.firestore();

    // Find chats where user is a participant
    let query: admin.firestore.Query = db
      .collection("chats")
      .where("participantIds", "array-contains", uid)
      .orderBy("updatedAt", "desc");

    const chatsSnap = await query.limit(50).get();

    let chats = chatsSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);

    // Filter by orderId if provided
    if (orderId) {
      chats = chats.filter((c) => c.orderId === orderId);
    }

    res.json({ chats });
  } catch (error) {
    functions.logger.error("Error fetching chats", error);
    res.status(500).json({ error: "Erro ao buscar conversas" });
  }
});

/**
 * GET /api/chats/:chatId
 * Get a specific chat by ID.
 */
router.get("/:chatId", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const chatId = String(req.params.chatId);

  try {
    const db = admin.firestore();
    const chatDoc = await db.collection("chats").doc(chatId).get();

    if (!chatDoc.exists) {
      res.status(404).json({ error: "Conversa não encontrada" });
      return;
    }

    const chatData = chatDoc.data()!;

    // Verify participant access
    if (!chatData.participantIds?.includes(uid)) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    res.json({ id: chatDoc.id, ...serializeTimestamps(chatData) });
  } catch (error) {
    functions.logger.error("Error fetching chat", error);
    res.status(500).json({ error: "Erro ao buscar conversa" });
  }
});

/**
 * POST /api/chats
 * Start a new chat or return existing one.
 * Body:
 *   tenantId: string (required)
 *   orderId?: string (optional)
 */
router.post("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { tenantId, orderId } = req.body;

  if (!tenantId) {
    res.status(400).json({ error: "tenantId é obrigatório" });
    return;
  }

  try {
    const db = admin.firestore();

    // Check if chat already exists between this buyer and tenant
    let existingQuery: admin.firestore.Query = db
      .collection("chats")
      .where("buyerUserId", "==", uid)
      .where("tenantId", "==", tenantId);

    if (orderId) {
      existingQuery = existingQuery.where("orderId", "==", orderId);
    }

    const existingSnap = await existingQuery.limit(1).get();

    // Get user and tenant info for display names (needed for both new and existing chats)
    const [userDoc, tenantDoc] = await Promise.all([
      db.collection("users").doc(uid).get(),
      db.collection("tenants").doc(tenantId).get(),
    ]);

    const userData = userDoc.data();
    const tenantData = tenantDoc.data();

    if (!tenantDoc.exists) {
      res.status(404).json({ error: "Loja não encontrada" });
      return;
    }

    // Resolve tenant display name — prefer tradeName/name, fall back to owner user's displayName
    let resolvedTenantName =
      (tenantData?.tradeName || tenantData?.name || tenantData?.businessName || "").toString().trim();
    if (!resolvedTenantName) {
      const ownerUserId = (tenantData?.ownerUserId || tenantData?.ownerId || "") as string;
      if (ownerUserId) {
        try {
          const ownerDoc = await db.collection("users").doc(ownerUserId).get();
          resolvedTenantName = (ownerDoc.data()?.displayName as string | undefined || "").trim();
        } catch {
          // Non-fatal
        }
      }
    }
    if (!resolvedTenantName) resolvedTenantName = "Loja";

    const resolvedBuyerName =
      (userData?.displayName || userData?.name || "").toString().trim() || "Cliente";

    if (!existingSnap.empty) {
      const existingDoc = existingSnap.docs[0];
      const existingData = existingDoc.data();

      // Patch stale/missing participant names in place so the AppBar always shows
      // the actual names, even for chats created before these fields were added.
      const patch: Record<string, unknown> = {};
      if (!existingData.tenantName || existingData.tenantName === "Loja") {
        patch.tenantName = resolvedTenantName;
      }
      if (!existingData.buyerName || existingData.buyerName === "Cliente") {
        patch.buyerName = resolvedBuyerName;
      }
      if (Object.keys(patch).length > 0) {
        await existingDoc.ref.update(patch);
        Object.assign(existingData, patch);
      }

      res.json({ id: existingDoc.id, ...serializeTimestamps(existingData) });
      return;
    }

    // Find seller user ID (owner of the tenant)
    const sellerSnap = await db
      .collection("users")
      .where("tenantId", "==", tenantId)
      .where("role", "in", ["owner", "admin"])
      .limit(1)
      .get();

    const sellerUserId = sellerSnap.empty ? tenantId : sellerSnap.docs[0].id;

    const now = admin.firestore.Timestamp.now();
    const chatId = uuidv4();

    const chatData: Record<string, unknown> = {
      id: chatId,
      tenantId,
      buyerUserId: uid,
      orderId: orderId || null,
      tenantName: resolvedTenantName,
      buyerName: resolvedBuyerName,
      status: "active",
      lastMessage: null,
      unreadByBuyer: 0,
      unreadByTenant: 0,
      participantIds: [uid, sellerUserId],
      participants: [uid, sellerUserId],
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("chats").doc(chatId).set(chatData);

    functions.logger.info("Chat created", { chatId, buyerUserId: uid, tenantId });

    res.status(201).json(serializeTimestamps(chatData));
  } catch (error) {
    functions.logger.error("Error creating chat", error);
    res.status(500).json({ error: "Erro ao criar conversa" });
  }
});

// ============================================================================
// Message Endpoints
// ============================================================================

/**
 * GET /api/chats/:chatId/messages
 * Get messages for a chat (paginated).
 * Query params:
 *   limit (default: 50)
 *   before (message ID for cursor pagination)
 */
router.get("/:chatId/messages", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const chatId = String(req.params.chatId);
  const limit = Math.min(parseInt(String(req.query.limit || "50")), 100);
  const before = req.query.before ? String(req.query.before) : undefined;

  try {
    const db = admin.firestore();

    // Verify participant access
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      res.status(404).json({ error: "Conversa não encontrada" });
      return;
    }

    if (!chatDoc.data()?.participantIds?.includes(uid)) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    let query: admin.firestore.Query = db
      .collection("chats")
      .doc(chatId)
      .collection("messages")
      .orderBy("createdAt", "asc");

    // Cursor pagination: get messages before a specific one
    if (before) {
      const beforeDoc = await db
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(before)
        .get();

      if (beforeDoc.exists) {
        query = db
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .orderBy("createdAt", "desc")
          .startAfter(beforeDoc)
          .limit(limit);

        const snap = await query.get();
        const messages = snap.docs
          .map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>)
          .reverse();

        const oldestMessageId = messages.length > 0 ? (messages[0] as Record<string, unknown>).id : null;

        res.json({
          messages,
          hasMore: snap.size === limit,
          oldestMessageId,
        });
        return;
      }
    }

    // Default: get latest messages
    const snap = await query.limitToLast(limit).get();
    const messages = snap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }) as Record<string, unknown>);

    const oldestMessageId = messages.length > 0 ? (messages[0] as Record<string, unknown>).id : null;

    res.json({
      messages,
      hasMore: snap.size === limit,
      oldestMessageId,
    });
  } catch (error) {
    functions.logger.error("Error fetching messages", error);
    res.status(500).json({ error: "Erro ao buscar mensagens" });
  }
});

/**
 * POST /api/chats/:chatId/messages
 * Send a message in a chat.
 * Body:
 *   type: string ("text" | "image")
 *   text?: string (required for text type)
 *   imageUrl?: string (for image type)
 *   replyToId?: string
 *   replyToText?: string
 *   replyToSenderName?: string
 */
router.post("/:chatId/messages", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const chatId = String(req.params.chatId);
  const { type = "text", text, imageUrl, replyToId, replyToText, replyToSenderName } = req.body;

  if (type === "text" && (!text || !text.trim())) {
    res.status(400).json({ error: "Texto da mensagem é obrigatório" });
    return;
  }

  if (type === "text" && text.length > 5000) {
    res.status(400).json({ error: "Mensagem excede o limite de 5000 caracteres" });
    return;
  }

  if (type === "image" && !imageUrl) {
    res.status(400).json({ error: "URL da imagem é obrigatória" });
    return;
  }

  if (type === "image" && !imageUrl.startsWith("https://firebasestorage.googleapis.com/")) {
    res.status(400).json({ error: "URL da imagem inválida" });
    return;
  }

  try {
    const db = admin.firestore();

    // Verify participant access and get chat data
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      res.status(404).json({ error: "Conversa não encontrada" });
      return;
    }

    const chatData = chatDoc.data()!;

    if (!chatData.participantIds?.includes(uid)) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    const isBuyer = uid === chatData.buyerUserId;
    const now = admin.firestore.Timestamp.now();
    const messageId = uuidv4();

    const messageData: Record<string, unknown> = {
      id: messageId,
      chatId,
      type,
      text: type === "text" ? text.trim() : null,
      imageUrl: type === "image" ? imageUrl : null,
      sentBy: uid,
      senderId: uid,
      isFromBuyer: isBuyer,
      readAt: null,
      createdAt: now,
      updatedAt: now,
    };

    // Add reply reference if provided
    if (replyToId) {
      messageData.replyToId = replyToId;
      messageData.replyToText = replyToText || null;
      messageData.replyToSenderName = replyToSenderName || null;
    }

    // Save message
    await db
      .collection("chats")
      .doc(chatId)
      .collection("messages")
      .doc(messageId)
      .set(messageData);

    // Update chat's last message and unread counts
    const messagePreview = type === "text" ? text.trim().substring(0, 100) : "[Imagem]";
    const chatUpdate: Record<string, unknown> = {
      lastMessage: {
        text: messagePreview,
        sentAt: now,
        sentBy: uid,
        isFromBuyer: isBuyer,
      },
      updatedAt: now,
    };

    // Increment unread count for the other party
    if (isBuyer) {
      chatUpdate.unreadByTenant = admin.firestore.FieldValue.increment(1);
    } else {
      chatUpdate.unreadByBuyer = admin.firestore.FieldValue.increment(1);
    }

    await db.collection("chats").doc(chatId).update(chatUpdate);

    // Send push notification to the other participant
    await sendMessageNotification(db, chatData, uid, isBuyer, messagePreview);

    functions.logger.info("Message sent", { chatId, messageId, type });

    res.status(201).json(serializeTimestamps(messageData));
  } catch (error) {
    functions.logger.error("Error sending message", error);
    res.status(500).json({ error: "Erro ao enviar mensagem" });
  }
});

/**
 * POST /api/chats/:chatId/read
 * Mark all messages in a chat as read for the current user.
 */
router.post("/:chatId/read", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const chatId = String(req.params.chatId);

  try {
    const db = admin.firestore();

    // Verify participant access
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      res.status(404).json({ error: "Conversa não encontrada" });
      return;
    }

    const chatData = chatDoc.data()!;

    if (!chatData.participantIds?.includes(uid)) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    const isBuyer = uid === chatData.buyerUserId;
    const now = admin.firestore.Timestamp.now();

    // Reset unread count for current user
    const chatUpdate: Record<string, unknown> = {};
    if (isBuyer) {
      chatUpdate.unreadByBuyer = 0;
    } else {
      chatUpdate.unreadByTenant = 0;
    }

    await db.collection("chats").doc(chatId).update(chatUpdate);

    // Mark unread messages from the other party as read
    const unreadSnap = await db
      .collection("chats")
      .doc(chatId)
      .collection("messages")
      .where("sentBy", "!=", uid)
      .where("readAt", "==", null)
      .limit(100)
      .get();

    if (!unreadSnap.empty) {
      const batch = db.batch();
      for (const doc of unreadSnap.docs) {
        batch.update(doc.ref, { readAt: now });
      }
      await batch.commit();
    }

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error marking chat as read", error);
    res.status(500).json({ error: "Erro ao marcar como lido" });
  }
});

// ============================================================================
// Helpers
// ============================================================================

/**
 * Send push notification for new message.
 */
async function sendMessageNotification(
  db: admin.firestore.Firestore,
  chatData: admin.firestore.DocumentData,
  senderUid: string,
  senderIsBuyer: boolean,
  messagePreview: string
): Promise<void> {
  try {
    // Determine recipient
    const recipientIds = (chatData.participantIds as string[]).filter(
      (id: string) => id !== senderUid
    );

    if (recipientIds.length === 0) return;

    const senderName = senderIsBuyer
      ? chatData.buyerName || "Cliente"
      : chatData.tenantName || "Loja";

    for (const recipientId of recipientIds) {
      const userDoc = await db.collection("users").doc(recipientId).get();
      const userData = userDoc.data();
      const fcmTokens = userData?.fcmTokens || (userData?.fcmToken ? [userData.fcmToken] : []);

      for (const token of fcmTokens) {
        try {
          await admin.messaging().send({
            token,
            notification: {
              title: senderName,
              body: messagePreview,
            },
            data: {
              type: "new_message",
              chatId: chatData.id,
            },
            android: {
              priority: "high",
              notification: {
                channelId: "chat_messages",
              },
            },
            apns: {
              payload: {
                aps: { sound: "default", badge: 1 },
              },
            },
          });
        } catch { /* token may be invalid */ }
      }

      // Create in-app notification
      const notifId = uuidv4();
      await db.collection("notifications").doc(notifId).set({
        id: notifId,
        userId: recipientId,
        title: `Nova mensagem de ${senderName}`,
        body: messagePreview,
        type: "new_message",
        data: { chatId: chatData.id },
        isRead: false,
        createdAt: admin.firestore.Timestamp.now(),
      });
    }
  } catch (error) {
    functions.logger.warn("Error sending message notification", error);
  }
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
