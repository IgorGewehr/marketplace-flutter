import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { AuthenticatedRequest, getTenantForUser } from "../middleware/auth";

const router = Router();

// ============================================================================
// Buyer: Apply & List My Applications
// ============================================================================

/**
 * POST /api/job-applications
 * Apply to a job listing.
 *
 * Body: jobId, coverLetter?, applicantPhone?, applicantEmail?
 */
router.post("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { jobId, coverLetter, applicantPhone, applicantEmail } = req.body;

  if (!jobId) {
    res.status(400).json({ error: "jobId é obrigatório" });
    return;
  }

  if (coverLetter && typeof coverLetter === "string" && coverLetter.length > 3000) {
    res.status(400).json({ error: "Carta de apresentação deve ter no máximo 3000 caracteres" });
    return;
  }

  try {
    const db = admin.firestore();

    // Verify job exists and is active
    const jobDoc = await db.collection("products").doc(jobId).get();
    if (!jobDoc.exists || jobDoc.data()!.listingType !== "job" || jobDoc.data()!.status !== "active") {
      res.status(404).json({ error: "Vaga não encontrada ou inativa" });
      return;
    }

    // Check for duplicate application
    const existingSnap = await db.collection("job_applications")
      .where("jobId", "==", jobId)
      .where("applicantUserId", "==", uid)
      .where("status", "in", ["pending", "accepted"])
      .limit(1)
      .get();

    if (!existingSnap.empty) {
      res.status(409).json({ error: "Você já se candidatou a esta vaga" });
      return;
    }

    // Get applicant info
    const userDoc = await db.collection("users").doc(uid).get();
    const userData = userDoc.data() || {};

    const now = admin.firestore.Timestamp.now();
    const applicationId = uuidv4();
    const jobData = jobDoc.data()!;

    const applicationData: Record<string, unknown> = {
      id: applicationId,
      jobId,
      jobTitle: jobData.name || "",
      tenantId: jobData.tenantId,
      applicantUserId: uid,
      applicantName: userData.displayName || "",
      applicantEmail: applicantEmail || userData.email || "",
      applicantPhone: applicantPhone || userData.phone || null,
      coverLetter: coverLetter ? String(coverLetter).substring(0, 3000) : null,
      status: "pending",
      createdAt: now,
      updatedAt: now,
    };

    await db.collection("job_applications").doc(applicationId).set(applicationData);

    functions.logger.info("Job application created", { uid, applicationId, jobId });

    res.status(201).json(serializeTimestamps(applicationData));
  } catch (error) {
    functions.logger.error("Error creating job application", error);
    res.status(500).json({ error: "Erro ao criar candidatura" });
  }
});

/**
 * GET /api/job-applications
 * List current user's job applications.
 *
 * Query: page, limit, status
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);
  const status = req.query.status ? String(req.query.status) : undefined;

  try {
    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("job_applications")
      .where("applicantUserId", "==", uid)
      .orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    const offset = (page - 1) * limit;
    const snap = await query.offset(offset).limit(limit).get();

    const applications = snap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }));

    res.json({ applications, total, page, limit });
  } catch (error) {
    functions.logger.error("Error fetching applications", error);
    res.status(500).json({ error: "Erro ao buscar candidaturas" });
  }
});

/**
 * DELETE /api/job-applications/:id
 * Withdraw an application (buyer only).
 */
router.delete("/:id", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const applicationId = String(req.params.id);

  try {
    const db = admin.firestore();
    const ref = db.collection("job_applications").doc(applicationId);
    const doc = await ref.get();

    if (!doc.exists) {
      res.status(404).json({ error: "Candidatura não encontrada" });
      return;
    }

    if (doc.data()!.applicantUserId !== uid) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    await ref.update({
      status: "withdrawn",
      updatedAt: admin.firestore.Timestamp.now(),
    });

    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error withdrawing application", error);
    res.status(500).json({ error: "Erro ao cancelar candidatura" });
  }
});

// ============================================================================
// Seller: View & Manage Applications
// ============================================================================

/**
 * GET /api/job-applications/job/:jobId
 * List applications for a specific job (seller only).
 */
router.get("/job/:jobId", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const jobId = String(req.params.jobId);
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();

    // Verify job belongs to this tenant
    const jobDoc = await db.collection("products").doc(jobId).get();
    if (!jobDoc.exists || jobDoc.data()!.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    let query: admin.firestore.Query = db
      .collection("job_applications")
      .where("jobId", "==", jobId)
      .orderBy("createdAt", "desc");

    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    const offset = (page - 1) * limit;
    const snap = await query.offset(offset).limit(limit).get();

    const applications = snap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }));

    res.json({ applications, total, page, limit });
  } catch (error) {
    functions.logger.error("Error fetching job applications", error);
    res.status(500).json({ error: "Erro ao buscar candidaturas" });
  }
});

/**
 * PATCH /api/job-applications/:id/status
 * Update application status (seller: accepted/rejected).
 *
 * Body: status ("accepted" | "rejected")
 */
router.patch("/:id/status", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const applicationId = String(req.params.id);
  const { status } = req.body;

  if (!status || !["accepted", "rejected"].includes(status)) {
    res.status(400).json({ error: "Status deve ser 'accepted' ou 'rejected'" });
    return;
  }

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const ref = db.collection("job_applications").doc(applicationId);
    const doc = await ref.get();

    if (!doc.exists) {
      res.status(404).json({ error: "Candidatura não encontrada" });
      return;
    }

    if (doc.data()!.tenantId !== tenantId) {
      res.status(403).json({ error: "Acesso negado" });
      return;
    }

    await ref.update({
      status,
      updatedAt: admin.firestore.Timestamp.now(),
    });

    const updatedDoc = await ref.get();
    res.json(serializeTimestamps(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error updating application status", error);
    res.status(500).json({ error: "Erro ao atualizar candidatura" });
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
