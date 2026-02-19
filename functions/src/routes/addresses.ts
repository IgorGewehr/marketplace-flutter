import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest } from "../middleware/auth";

const router = Router();

// ============================================================================
// Address Endpoints
// ============================================================================

/**
 * GET /api/addresses
 * List all addresses for the authenticated user.
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const db = admin.firestore();
    const addressesSnap = await db
      .collection("users")
      .doc(uid)
      .collection("addresses")
      .orderBy("createdAt", "desc")
      .get();

    const addresses = addressesSnap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }));

    res.json({ addresses });
  } catch (error) {
    functions.logger.error("Error fetching addresses", error);
    res.status(500).json({ error: "Erro ao buscar enderecos" });
  }
});

/**
 * POST /api/addresses
 * Create a new address for the authenticated user.
 *
 * Body:
 *   label: string (e.g. "Casa", "Trabalho")
 *   street: string
 *   number: string
 *   complement?: string
 *   neighborhood: string
 *   city: string
 *   state: string
 *   zipCode: string
 *   isDefault?: boolean
 */
router.post("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  const {
    label,
    street,
    number,
    complement,
    neighborhood,
    city,
    state,
    zipCode,
    isDefault,
  } = req.body;

  // Validate required fields
  if (!street || !number || !neighborhood || !city || !state || !zipCode) {
    res.status(400).json({ error: "Campos obrigatorios: street, number, neighborhood, city, state, zipCode" });
    return;
  }

  try {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const addressId = uuidv4();
    const addressesRef = db.collection("users").doc(uid).collection("addresses");

    // If this address should be default, unset all other defaults
    if (isDefault) {
      const existingDefaults = await addressesRef
        .where("isDefault", "==", true)
        .get();

      if (!existingDefaults.empty) {
        const batch = db.batch();
        for (const doc of existingDefaults.docs) {
          batch.update(doc.ref, { isDefault: false, updatedAt: now });
        }
        await batch.commit();
      }
    }

    // If this is the first address, make it default automatically
    const existingSnap = await addressesRef.limit(1).get();
    const shouldBeDefault = isDefault || existingSnap.empty;

    const addressData: Record<string, unknown> = {
      id: addressId,
      label: label || null,
      street,
      number,
      complement: complement || null,
      neighborhood,
      city,
      state,
      zipCode,
      isDefault: shouldBeDefault,
      createdAt: now,
      updatedAt: now,
    };

    await addressesRef.doc(addressId).set(addressData);

    functions.logger.info("Address created", { uid, addressId });

    res.status(201).json(serializeTimestamps(addressData));
  } catch (error) {
    functions.logger.error("Error creating address", error);
    res.status(500).json({ error: "Erro ao criar endereco" });
  }
});

/**
 * PUT /api/addresses/:id
 * Update an existing address.
 */
router.put("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const addressId = String(req.params.id);

  const {
    label,
    street,
    number,
    complement,
    neighborhood,
    city,
    state,
    zipCode,
    isDefault,
  } = req.body;

  try {
    const db = admin.firestore();
    const addressRef = db
      .collection("users")
      .doc(uid)
      .collection("addresses")
      .doc(addressId);

    const addressDoc = await addressRef.get();

    if (!addressDoc.exists) {
      res.status(404).json({ error: "Endereco nao encontrado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();
    const updateData: Record<string, unknown> = { updatedAt: now };

    if (label !== undefined) updateData.label = label || null;
    if (street !== undefined) updateData.street = street;
    if (number !== undefined) updateData.number = number;
    if (complement !== undefined) updateData.complement = complement || null;
    if (neighborhood !== undefined) updateData.neighborhood = neighborhood;
    if (city !== undefined) updateData.city = city;
    if (state !== undefined) updateData.state = state;
    if (zipCode !== undefined) updateData.zipCode = zipCode;

    // If setting as default, unset all other defaults
    if (isDefault === true) {
      const addressesRef = db.collection("users").doc(uid).collection("addresses");
      const existingDefaults = await addressesRef
        .where("isDefault", "==", true)
        .get();

      if (!existingDefaults.empty) {
        const batch = db.batch();
        for (const doc of existingDefaults.docs) {
          if (doc.id !== addressId) {
            batch.update(doc.ref, { isDefault: false, updatedAt: now });
          }
        }
        await batch.commit();
      }
      updateData.isDefault = true;
    } else if (isDefault === false) {
      updateData.isDefault = false;
    }

    await addressRef.update(updateData);

    const updatedDoc = await addressRef.get();
    res.json(serializeTimestamps(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error updating address", error);
    res.status(500).json({ error: "Erro ao atualizar endereco" });
  }
});

/**
 * DELETE /api/addresses/:id
 * Delete an address.
 */
router.delete("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const addressId = String(req.params.id);

  try {
    const db = admin.firestore();
    const addressRef = db
      .collection("users")
      .doc(uid)
      .collection("addresses")
      .doc(addressId);

    const addressDoc = await addressRef.get();

    if (!addressDoc.exists) {
      res.status(404).json({ error: "Endereco nao encontrado" });
      return;
    }

    const wasDefault = addressDoc.data()?.isDefault === true;

    await addressRef.delete();

    // If deleted address was default, set the most recent remaining address as default
    if (wasDefault) {
      const addressesRef = db.collection("users").doc(uid).collection("addresses");
      const remaining = await addressesRef
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();

      if (!remaining.empty) {
        await remaining.docs[0].ref.update({
          isDefault: true,
          updatedAt: admin.firestore.Timestamp.now(),
        });
      }
    }

    functions.logger.info("Address deleted", { uid, addressId });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error deleting address", error);
    res.status(500).json({ error: "Erro ao excluir endereco" });
  }
});

/**
 * PATCH /api/addresses/:id/default
 * Set an address as the default address.
 */
router.patch("/:id/default", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const addressId = String(req.params.id);

  try {
    const db = admin.firestore();
    const addressesRef = db.collection("users").doc(uid).collection("addresses");
    const addressRef = addressesRef.doc(addressId);

    const addressDoc = await addressRef.get();

    if (!addressDoc.exists) {
      res.status(404).json({ error: "Endereco nao encontrado" });
      return;
    }

    const now = admin.firestore.Timestamp.now();

    // Unset all other defaults
    const existingDefaults = await addressesRef
      .where("isDefault", "==", true)
      .get();

    if (!existingDefaults.empty) {
      const batch = db.batch();
      for (const doc of existingDefaults.docs) {
        if (doc.id !== addressId) {
          batch.update(doc.ref, { isDefault: false, updatedAt: now });
        }
      }
      await batch.commit();
    }

    // Set this address as default
    await addressRef.update({ isDefault: true, updatedAt: now });

    const updatedDoc = await addressRef.get();

    functions.logger.info("Default address updated", { uid, addressId });

    res.json(serializeTimestamps(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error setting default address", error);
    res.status(500).json({ error: "Erro ao definir endereco padrao" });
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
