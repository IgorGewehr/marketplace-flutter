import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();

// ============================================================================
// Auth Endpoints
// ============================================================================

/**
 * POST /api/auth/register
 * Register a new user in Firestore after Firebase Auth creation.
 *
 * Body:
 *   email: string
 *   displayName: string
 */
router.post("/register", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { email, displayName } = req.body;

  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // Check if user already exists
    const existingUser = await db.collection("users").doc(uid).get();
    if (existingUser.exists) {
      res.json(serializeTimestamps(existingUser.data()!));
      return;
    }

    const userData: Record<string, unknown> = {
      id: uid,
      type: "buyer",
      email: email || "",
      displayName: displayName || "",
      photoURL: null,
      phone: null,
      fcmTokens: [],
      isActive: true,
      lastLoginAt: now,
      addresses: [],
      preferences: {
        notifyPromotions: true,
        notifyOrderUpdates: true,
        preferredCategories: [],
        searchRadius: 10,
      },
      role: null,
      tenantId: null,
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("users").doc(uid).set(userData);

    functions.logger.info("User registered", { uid, email });

    res.status(201).json(serializeTimestamps(userData));
  } catch (error) {
    functions.logger.error("Error registering user", error);
    res.status(500).json({ error: "Erro ao registrar usuario" });
  }
});

/**
 * GET /api/auth/me
 * Get current authenticated user profile.
 */
router.get("/me", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const db = admin.firestore();
    const userDoc = await db.collection("users").doc(uid).get();

    if (!userDoc.exists) {
      // Auto-create user from Firebase Auth record
      const authUser = await admin.auth().getUser(uid);
      const now = admin.firestore.Timestamp.now();

      const userData: Record<string, unknown> = {
        id: uid,
        type: "buyer",
        email: authUser.email || "",
        displayName: authUser.displayName || "",
        photoURL: authUser.photoURL || null,
        phone: authUser.phoneNumber || null,
        fcmTokens: [],
        isActive: true,
        lastLoginAt: now,
        addresses: [],
        preferences: {
          notifyPromotions: true,
          notifyOrderUpdates: true,
          preferredCategories: [],
          searchRadius: 10,
        },
        role: null,
        tenantId: null,
        createdAt: now,
        updatedAt: now,
      };

      await db.collection("users").doc(uid).set(userData);
      res.json(serializeTimestamps(userData));
      return;
    }

    // Update last login
    await db.collection("users").doc(uid).update({
      lastLoginAt: admin.firestore.Timestamp.now(),
    });

    res.json(serializeTimestamps(userDoc.data()!));
  } catch (error) {
    functions.logger.error("Error fetching user", error);
    res.status(500).json({ error: "Erro ao buscar usuario" });
  }
});

/**
 * PATCH /api/auth/me
 * Update current user profile.
 *
 * Body (all optional):
 *   displayName: string
 *   phone: string
 *   photoURL: string
 */
router.patch("/me", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { displayName, phone, photoURL } = req.body;

  try {
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      res.status(404).json({ error: "Usuario nao encontrado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const updateData: Record<string, unknown> = { updatedAt: now };

    if (displayName !== undefined) updateData.displayName = displayName;
    if (phone !== undefined) updateData.phone = phone;
    if (photoURL !== undefined) updateData.photoURL = photoURL;

    await userRef.update(updateData);

    const updatedDoc = await userRef.get();
    res.json(serializeTimestamps(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error updating user", error);
    res.status(500).json({ error: "Erro ao atualizar usuario" });
  }
});

/**
 * POST /api/auth/complete-profile
 * Complete user profile with phone and document.
 *
 * Body:
 *   phone: string
 *   cpfCnpj: string
 *   birthDate?: string (ISO)
 */
router.post("/complete-profile", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { phone, cpfCnpj, birthDate } = req.body;

  if (!phone) {
    res.status(400).json({ error: "Telefone obrigatorio" });
    return;
  }

  try {
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      res.status(404).json({ error: "Usuario nao encontrado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const updateData: Record<string, unknown> = {
      phone,
      updatedAt: now,
    };

    if (cpfCnpj) {
      updateData.document = cpfCnpj.replace(/\D/g, "");
      updateData.documentType = cpfCnpj.replace(/\D/g, "").length > 11 ? "CNPJ" : "CPF";
    }

    if (birthDate) {
      updateData.birthDate = birthDate;
    }

    await userRef.update(updateData);

    const updatedDoc = await userRef.get();
    res.json(serializeTimestamps(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error completing profile", error);
    res.status(500).json({ error: "Erro ao completar perfil" });
  }
});

/**
 * POST /api/auth/become-seller
 * Upgrade a buyer to seller - creates a tenant.
 *
 * Body:
 *   tradeName: string
 *   documentNumber: string
 *   documentType: string (CPF or CNPJ)
 *   phone?: string
 *   whatsapp?: string
 */
router.post("/become-seller", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { tradeName, documentNumber, documentType, phone, whatsapp } = req.body;

  if (!tradeName || !documentNumber || !documentType) {
    res.status(400).json({ error: "tradeName, documentNumber e documentType sao obrigatorios" });
    return;
  }

  try {
    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      res.status(404).json({ error: "Usuario nao encontrado" });
      return;
    }

    const userData = userDoc.data()!;

    // Check if already a seller
    if (userData.tenantId) {
      res.json(serializeTimestamps(userData));
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const tenantId = uuidv4();

    // Create tenant
    const tenantData: Record<string, unknown> = {
      id: tenantId,
      tradeName,
      documentNumber: documentNumber.replace(/\D/g, ""),
      documentType,
      ownerUserId: uid,
      phone: phone || userData.phone || null,
      whatsapp: whatsapp || null,
      isActive: true,
      marketplaceStats: {
        totalProducts: 0,
        totalOrders: 0,
        totalRevenue: 0,
        averageRating: 0,
        totalReviews: 0,
      },
      mpConnection: {
        isConnected: false,
      },
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("tenants").doc(tenantId).set(tenantData);

    // Update user to seller type
    await userRef.update({
      type: "seller",
      tenantId,
      role: "owner",
      updatedAt: now,
    });

    const updatedUser = await userRef.get();

    functions.logger.info("User became seller", { uid, tenantId, tradeName });

    res.status(201).json(serializeTimestamps(updatedUser.data()!));
  } catch (error) {
    functions.logger.error("Error becoming seller", error);
    res.status(500).json({ error: "Erro ao criar loja" });
  }
});

/**
 * POST /api/auth/me/fcm-token
 * Register an FCM push notification token.
 *
 * Body:
 *   token: string
 */
router.post("/me/fcm-token", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { token } = req.body;

  if (!token) {
    res.status(400).json({ error: "Token obrigatorio" });
    return;
  }

  try {
    const db = admin.firestore();
    await db.collection("users").doc(uid).update({
      fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error registering FCM token", error);
    res.status(500).json({ error: "Erro ao registrar token" });
  }
});

/**
 * DELETE /api/auth/me/fcm-token
 * Remove an FCM push notification token.
 *
 * Body:
 *   token: string
 */
router.delete("/me/fcm-token", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { token } = req.body;

  if (!token) {
    res.status(400).json({ error: "Token obrigatorio" });
    return;
  }

  try {
    const db = admin.firestore();
    await db.collection("users").doc(uid).update({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(token),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error removing FCM token", error);
    res.status(500).json({ error: "Erro ao remover token" });
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
