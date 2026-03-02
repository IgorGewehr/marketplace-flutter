import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";

const router = Router();

// ============================================================================
// Appointment Endpoints
// ============================================================================

const DAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];

/**
 * POST /api/appointments
 * Create a new appointment (buyer books a slot).
 *
 * Body: { serviceId, date, startTime, notes? }
 */
router.post("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { serviceId, date, startTime, notes } = req.body;

  if (!serviceId || !date || !startTime) {
    res.status(400).json({ error: "serviceId, date e startTime são obrigatórios" });
    return;
  }

  // Validate date format
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    res.status(400).json({ error: "Formato de data inválido. Use YYYY-MM-DD" });
    return;
  }

  // Validate time format
  if (!/^\d{2}:\d{2}$/.test(startTime)) {
    res.status(400).json({ error: "Formato de horário inválido. Use HH:mm" });
    return;
  }

  try {
    const db = admin.firestore();

    // Get service
    const serviceDoc = await db.collection("services").doc(serviceId).get();
    if (!serviceDoc.exists) {
      res.status(404).json({ error: "Serviço não encontrado" });
      return;
    }

    const service = serviceDoc.data()!;

    // Check service is active
    if (service.status !== "active") {
      res.status(400).json({ error: "Serviço não está ativo" });
      return;
    }

    // Check schedule is enabled
    if (!service.scheduleEnabled) {
      res.status(400).json({ error: "Agendamento não está habilitado para este serviço" });
      return;
    }

    // Check date is in the future
    const appointmentDate = new Date(date + "T00:00:00");
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    if (appointmentDate < today) {
      res.status(400).json({ error: "Data deve ser futura" });
      return;
    }

    // Check day of week is in availableDays
    const dayOfWeek = DAY_NAMES[appointmentDate.getDay()];
    const availableDays: string[] = service.availableDays || [];
    if (availableDays.length > 0 && !availableDays.includes(dayOfWeek)) {
      res.status(400).json({ error: "Dia da semana não disponível para este serviço" });
      return;
    }

    // Check time is within service hours
    const serviceHours = service.serviceHours || {};
    const dayHours = serviceHours[dayOfWeek];
    if (dayHours) {
      const [hoursStart, hoursEnd] = dayHours.split("-");
      if (hoursStart && hoursEnd) {
        if (startTime < hoursStart || startTime >= hoursEnd) {
          res.status(400).json({ error: "Horário fora do período de atendimento" });
          return;
        }
      }
    }

    // Calculate endTime
    const slotDuration = service.slotDurationMinutes || 60;
    const [h, m] = startTime.split(":").map(Number);
    const endMinutes = h * 60 + m + slotDuration;
    const endH = Math.floor(endMinutes / 60).toString().padStart(2, "0");
    const endM = (endMinutes % 60).toString().padStart(2, "0");
    const endTime = `${endH}:${endM}`;

    // Check for conflicting appointments
    const conflictsSnap = await db
      .collection("appointments")
      .where("serviceId", "==", serviceId)
      .where("date", "==", date)
      .where("status", "in", ["pending", "confirmed"])
      .get();

    const hasConflict = conflictsSnap.docs.some((doc) => {
      const apt = doc.data();
      // Check time overlap
      return startTime < apt.endTime && endTime > apt.startTime;
    });

    if (hasConflict) {
      res.status(409).json({ error: "Horário já reservado" });
      return;
    }

    // Get buyer info
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() || {};
    const buyerName = userData.displayName || userData.name || "Comprador";

    const now = admin.firestore.Timestamp.now();
    const appointmentId = uuidv4();
    const tenantId = service.tenantId;

    const appointmentData = {
      id: appointmentId,
      serviceId,
      serviceName: service.name || "",
      tenantId,
      buyerUserId: uid,
      buyerName,
      date,
      startTime,
      endTime,
      status: "pending",
      notes: notes || null,
      chatId: null as string | null,
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("appointments").doc(appointmentId).set(appointmentData);

    // Create or find chat between buyer and tenant, send auto message
    try {
      const chatId = await getOrCreateChat(db, uid, tenantId);
      if (chatId) {
        appointmentData.chatId = chatId;
        await db.collection("appointments").doc(appointmentId).update({ chatId });

        const displayDate = `${date.split("-")[2]}/${date.split("-")[1]}/${date.split("-")[0]}`;
        const messageText =
          `📅 Agendamento solicitado\nServiço: ${service.name}\nData: ${displayDate}\nHorário: ${startTime} - ${endTime}`;

        const messageId = uuidv4();
        await db
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .set({
            id: messageId,
            senderId: uid,
            text: messageText,
            type: "system",
            createdAt: now,
          });

        await db.collection("chats").doc(chatId).update({
          lastMessage: messageText.substring(0, 100),
          lastMessageAt: now,
          updatedAt: now,
        });
      }
    } catch (chatError) {
      functions.logger.warn("Failed to create chat message for appointment", { chatError });
    }

    // Send FCM notification to seller
    try {
      const tenantDoc = await db.collection("tenants").doc(tenantId).get();
      const ownerUserId = tenantDoc.data()?.ownerUserId || tenantDoc.data()?.ownerId;
      if (ownerUserId) {
        const ownerDoc = await db.collection("users").doc(ownerUserId).get();
        const ownerData = ownerDoc.data();
        const fcmTokens = ownerData?.fcmTokens || (ownerData?.fcmToken ? [ownerData.fcmToken] : []);

        for (const token of fcmTokens) {
          try {
            await admin.messaging().send({
              token,
              notification: {
                title: "Novo agendamento!",
                body: `${buyerName} solicitou ${service.name} em ${date.split("-")[2]}/${date.split("-")[1]} às ${startTime}`,
              },
              data: { type: "appointment", appointmentId },
              android: { priority: "high" },
              apns: { payload: { aps: { sound: "default" } } },
            });
          } catch { /* token may be invalid */ }
        }
      }
    } catch (notifError) {
      functions.logger.warn("Failed to send appointment notification", { notifError });
    }

    functions.logger.info("Appointment created", { uid, appointmentId, serviceId, tenantId });

    res.status(201).json(serializeTimestamps(appointmentData));
  } catch (error) {
    functions.logger.error("Error creating appointment", error);
    res.status(500).json({ error: "Erro ao criar agendamento" });
  }
});

/**
 * GET /api/appointments
 * List appointments for the current user.
 * Sellers see their tenant's appointments, buyers see their own.
 *
 * Query params: status, dateFrom, dateTo, serviceId, page, limit
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "50")), 100);
  const status = req.query.status ? String(req.query.status) : undefined;
  const dateFrom = req.query.dateFrom ? String(req.query.dateFrom) : undefined;
  const dateTo = req.query.dateTo ? String(req.query.dateTo) : undefined;
  const serviceId = req.query.serviceId ? String(req.query.serviceId) : undefined;

  try {
    const db = admin.firestore();
    const tenantId = await getTenantForUser(uid);

    let query: admin.firestore.Query;

    if (tenantId) {
      // Seller: get appointments for their tenant
      query = db.collection("appointments").where("tenantId", "==", tenantId);
    } else {
      // Buyer: get their own appointments
      query = db.collection("appointments").where("buyerUserId", "==", uid);
    }

    if (status && status !== "all") {
      query = query.where("status", "==", status);
    }

    if (serviceId) {
      query = query.where("serviceId", "==", serviceId);
    }

    // Order by date, startTime
    query = query.orderBy("date", "asc").orderBy("startTime", "asc");

    const allSnap = await query.get();

    // Apply date filters in memory (Firestore can't combine string range with other where clauses easily)
    let appointments = allSnap.docs
      .map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }))
      .filter((apt: Record<string, unknown>) => {
        if (dateFrom && (apt.date as string) < dateFrom) return false;
        if (dateTo && (apt.date as string) > dateTo) return false;
        return true;
      });

    const total = appointments.length;
    const offset = (page - 1) * limit;
    appointments = appointments.slice(offset, offset + limit);

    res.json({
      appointments,
      total,
      page,
      limit,
    });
  } catch (error) {
    functions.logger.error("Error fetching appointments", error);
    res.status(500).json({ error: "Erro ao buscar agendamentos" });
  }
});

/**
 * PATCH /api/appointments/:id
 * Update appointment status.
 * Seller: confirm, cancel, complete, no_show
 * Buyer: cancel (if pending/confirmed and date is future)
 */
router.patch("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const appointmentId = String(req.params.id);
  const { status: newStatus } = req.body;

  if (!newStatus) {
    res.status(400).json({ error: "status é obrigatório" });
    return;
  }

  const validStatuses = ["confirmed", "cancelled", "completed", "no_show"];
  if (!validStatuses.includes(newStatus)) {
    res.status(400).json({ error: "Status inválido" });
    return;
  }

  try {
    const db = admin.firestore();
    const appointmentRef = db.collection("appointments").doc(appointmentId);
    const appointmentDoc = await appointmentRef.get();

    if (!appointmentDoc.exists) {
      res.status(404).json({ error: "Agendamento não encontrado" });
      return;
    }

    const appointment = appointmentDoc.data()!;
    const tenantId = await getTenantForUser(uid);
    const isSeller = tenantId === appointment.tenantId;
    const isBuyer = uid === appointment.buyerUserId;

    if (!isSeller && !isBuyer) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    // Buyer can only cancel
    if (isBuyer && !isSeller) {
      if (newStatus !== "cancelled") {
        res.status(403).json({ error: "Compradores só podem cancelar agendamentos" });
        return;
      }
      if (!["pending", "confirmed"].includes(appointment.status)) {
        res.status(400).json({ error: "Só é possível cancelar agendamentos pendentes ou confirmados" });
        return;
      }
    }

    // Seller status transitions
    if (isSeller) {
      const allowedTransitions: Record<string, string[]> = {
        pending: ["confirmed", "cancelled"],
        confirmed: ["completed", "cancelled", "no_show"],
      };
      const allowed = allowedTransitions[appointment.status] || [];
      if (!allowed.includes(newStatus)) {
        res.status(400).json({ error: `Não é possível mudar de '${appointment.status}' para '${newStatus}'` });
        return;
      }
    }

    const now = admin.firestore.Timestamp.now();
    await appointmentRef.update({
      status: newStatus,
      updatedAt: now,
    });

    // Send chat message about status change
    try {
      const chatId = appointment.chatId;
      if (chatId) {
        let messageText = "";
        switch (newStatus) {
          case "confirmed":
            messageText = `✅ Agendamento confirmado!\nServiço: ${appointment.serviceName}\nData: ${appointment.date}\nHorário: ${appointment.startTime} - ${appointment.endTime}`;
            break;
          case "cancelled":
            messageText = `❌ Agendamento cancelado\nServiço: ${appointment.serviceName}\nData: ${appointment.date}`;
            break;
          case "completed":
            messageText = `🎉 Serviço concluído!\nServiço: ${appointment.serviceName}`;
            break;
          case "no_show":
            messageText = `⚠️ Não comparecimento registrado\nServiço: ${appointment.serviceName}\nData: ${appointment.date}`;
            break;
        }

        if (messageText) {
          const messageId = uuidv4();
          await db
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .doc(messageId)
            .set({
              id: messageId,
              senderId: uid,
              text: messageText,
              type: "system",
              createdAt: now,
            });

          await db.collection("chats").doc(chatId).update({
            lastMessage: messageText.substring(0, 100),
            lastMessageAt: now,
            updatedAt: now,
          });
        }
      }
    } catch (chatError) {
      functions.logger.warn("Failed to send status change chat message", { chatError });
    }

    const updatedDoc = await appointmentRef.get();
    res.json(serializeTimestamps(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error updating appointment", error);
    res.status(500).json({ error: "Erro ao atualizar agendamento" });
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

/**
 * Get or create a chat between a buyer and a tenant.
 */
async function getOrCreateChat(
  db: admin.firestore.Firestore,
  buyerUid: string,
  tenantId: string,
): Promise<string | null> {
  // Find existing chat
  const existingSnap = await db
    .collection("chats")
    .where("participantIds", "array-contains", buyerUid)
    .where("tenantId", "==", tenantId)
    .limit(1)
    .get();

  if (!existingSnap.empty) {
    return existingSnap.docs[0].id;
  }

  // Find tenant owner
  const tenantDoc = await db.collection("tenants").doc(tenantId).get();
  if (!tenantDoc.exists) return null;
  const tenantData = tenantDoc.data()!;
  const ownerId = tenantData.ownerUserId || tenantData.ownerId;
  if (!ownerId) return null;

  // Create new chat
  const chatId = uuidv4();
  const now = admin.firestore.Timestamp.now();

  await db.collection("chats").doc(chatId).set({
    id: chatId,
    tenantId,
    participantIds: [buyerUid, ownerId],
    buyerId: buyerUid,
    sellerId: ownerId,
    lastMessage: null,
    lastMessageAt: now,
    createdAt: now,
    updatedAt: now,
  });

  return chatId;
}

export default router;
