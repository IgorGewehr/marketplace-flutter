import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { v4 as uuidv4 } from "uuid";
import { config } from "../config";
import { AuthenticatedRequest, getTenantForUser, getSellerMpTokens } from "../middleware/auth";
import { createBankTransfer } from "./client";
import { getValidSellerToken } from "./oauth";

const MINIMUM_WITHDRAWAL_AMOUNT = 5.0; // R$ 5,00 minimum

const router = Router();

/**
 * GET /api/wallet
 * Get seller's wallet balance.
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const walletDoc = await db.collection("wallets").doc(tenantId).get();

    if (!walletDoc.exists) {
      // Return empty wallet
      res.json({
        id: tenantId,
        tenantId,
        status: "active",
        balance: {
          available: 0,
          pending: 0,
          blocked: 0,
          total: 0,
        },
        bankAccount: null,
        gatewayProvider: "mercadopago",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
      return;
    }

    const data = walletDoc.data()!;
    res.json(serializeWallet(data));
  } catch (error) {
    functions.logger.error("Error fetching wallet", error);
    res.status(500).json({ error: "Erro ao buscar carteira" });
  }
});

/**
 * GET /api/wallet/transactions
 * Get wallet transaction history (paginated).
 */
router.get("/transactions", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const page = parseInt(String(req.query.page || "1"));
  const limit = Math.min(parseInt(String(req.query.limit || "20")), 50);
  const type = req.query.type ? String(req.query.type) : undefined;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("transactions")
      .where("tenantId", "==", tenantId)
      .orderBy("createdAt", "desc");

    if (type) {
      query = query.where("type", "==", type);
    }

    const countSnap = await query.count().get();
    const total = countSnap.data().count;

    const offset = (page - 1) * limit;
    const snap = await query.offset(offset).limit(limit).get();

    const transactions = snap.docs.map((doc) => {
      const data = doc.data();
      return serializeTimestamps(data);
    });

    res.json({
      transactions,
      total,
      page,
      limit,
      hasMore: offset + limit < total,
    });
  } catch (error) {
    functions.logger.error("Error fetching transactions", error);
    res.status(500).json({ error: "Erro ao buscar transações" });
  }
});

/**
 * POST /api/wallet/withdraw
 * Request a withdrawal to bank account / PIX.
 */
router.post("/withdraw", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { amount } = req.body;

  if (!amount || amount <= 0) {
    res.status(400).json({ error: "Valor inválido" });
    return;
  }

  if (amount < MINIMUM_WITHDRAWAL_AMOUNT) {
    res.status(400).json({ error: `Valor mínimo para saque é R$ ${MINIMUM_WITHDRAWAL_AMOUNT.toFixed(2)}` });
    return;
  }

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const walletRef = db.collection("wallets").doc(tenantId);

    // Use transaction for atomic balance update
    const withdrawal = await db.runTransaction(async (transaction) => {
      const walletSnap = await transaction.get(walletRef);

      if (!walletSnap.exists) {
        throw new Error("Carteira não encontrada");
      }

      const walletData = walletSnap.data()!;
      const available = walletData.balance?.available || 0;

      if (amount > available) {
        throw new Error("Saldo insuficiente");
      }

      if (walletData.status !== "active") {
        throw new Error("Carteira bloqueada");
      }

      const bankAccount = walletData.bankAccount;
      if (!bankAccount) {
        throw new Error("Conta bancária não cadastrada. Cadastre uma conta antes de solicitar saque.");
      }

      // Calculate withdrawal fee (optional - set to 0 for now)
      const withdrawalFee = 0;
      const netAmount = amount - withdrawalFee;

      // Create withdrawal record
      const withdrawalId = uuidv4();
      const now = admin.firestore.Timestamp.now();

      const withdrawalData: Record<string, unknown> = {
        id: withdrawalId,
        walletId: tenantId,
        tenantId,
        amount,
        fee: withdrawalFee,
        netAmount,
        status: "processing",
        bankAccount,
        createdAt: now,
        updatedAt: now,
      };

      // Update wallet balance - move to blocked until transfer completes
      transaction.update(walletRef, {
        "balance.available": available - amount,
        "balance.blocked": (walletData.balance?.blocked || 0) + amount,
        updatedAt: now,
      });

      // Create withdrawal document
      const withdrawalRef = db.collection("withdrawals").doc(withdrawalId);
      transaction.set(withdrawalRef, withdrawalData);

      // Create transaction record
      const txId = uuidv4();
      const txRef = db.collection("transactions").doc(txId);
      transaction.set(txRef, {
        id: txId,
        tenantId,
        type: "withdrawal",
        source: "marketplace",
        amount: -amount,
        fee: withdrawalFee,
        netAmount: -netAmount,
        description: `Saque para ${bankAccount.bankName} - Ag: ${bankAccount.branch} CC: ${bankAccount.accountNumber}`,
        status: "processing",
        walletId: tenantId,
        gatewayProvider: "mercadopago",
        metadata: {
          withdrawalId,
          bankAccount: {
            bankName: bankAccount.bankName,
            branch: bankAccount.branch,
            accountNumber: bankAccount.accountNumber,
          },
        },
        createdAt: now,
        updatedAt: now,
      });

      return { withdrawalData, withdrawalId, txId, bankAccount };
    });

    // Execute actual bank transfer via Mercado Pago (outside Firestore transaction)
    const { withdrawalId, txId, bankAccount: bankAcct } = withdrawal as {
      withdrawalData: Record<string, unknown>;
      withdrawalId: string;
      txId: string;
      bankAccount: Record<string, string>;
    };

    try {
      // Get seller's MP access token for the transfer
      let accessToken: string;
      try {
        accessToken = await getValidSellerToken(tenantId);
      } catch {
        // Fallback to platform token if seller not connected
        accessToken = config.mercadoPago.accessToken;
      }

      const idempotencyKey = `withdrawal-${withdrawalId}`;

      const transferResult = await createBankTransfer(
        accessToken,
        amount,
        {
          bank_id: bankAcct.bankCode,
          type: bankAcct.accountType === "savings" ? "savings" : "checking",
          number: `${bankAcct.branch}${bankAcct.accountNumber}${bankAcct.accountDigit}`,
          holder_name: bankAcct.holderName,
          holder_document: bankAcct.holderDocument.replace(/\D/g, ""),
        },
        withdrawalId,
        idempotencyKey
      );

      // Transfer initiated successfully - update status
      const now2 = admin.firestore.Timestamp.now();
      const batch = db.batch();

      batch.update(db.collection("withdrawals").doc(withdrawalId), {
        status: "completed",
        gatewayTransferId: transferResult.id || null,
        completedAt: now2,
        updatedAt: now2,
      });

      batch.update(db.collection("transactions").doc(txId), {
        status: "completed",
        gatewayTransactionId: transferResult.id?.toString() || null,
        updatedAt: now2,
      });

      // Move from blocked to actually deducted
      batch.update(db.collection("wallets").doc(tenantId), {
        "balance.blocked": admin.firestore.FieldValue.increment(-amount),
        "balance.total": admin.firestore.FieldValue.increment(-amount),
        updatedAt: now2,
      });

      await batch.commit();

      functions.logger.info("Withdrawal completed via MP", {
        tenantId,
        amount,
        withdrawalId,
        transferId: transferResult.id,
      });

      // Re-fetch for response
      const updatedDoc = await db.collection("withdrawals").doc(withdrawalId).get();
      res.status(201).json(serializeTimestamps(updatedDoc.data()!));
    } catch (transferError) {
      // Transfer failed - revert wallet balance
      functions.logger.error("Bank transfer failed, reverting balance", {
        tenantId,
        withdrawalId,
        error: transferError,
      });

      const now2 = admin.firestore.Timestamp.now();
      const batch = db.batch();

      batch.update(db.collection("withdrawals").doc(withdrawalId), {
        status: "failed",
        failureReason: transferError instanceof Error ? transferError.message : "Falha na transferência",
        updatedAt: now2,
      });

      batch.update(db.collection("transactions").doc(txId), {
        status: "failed",
        updatedAt: now2,
      });

      // Revert: move blocked back to available
      batch.update(db.collection("wallets").doc(tenantId), {
        "balance.available": admin.firestore.FieldValue.increment(amount),
        "balance.blocked": admin.firestore.FieldValue.increment(-amount),
        updatedAt: now2,
      });

      await batch.commit();

      res.status(500).json({ error: "Falha ao processar transferência bancária. Saldo foi restaurado." });
    }
  } catch (error) {
    functions.logger.error("Error requesting withdrawal", error);
    const message = error instanceof Error ? error.message : "Erro ao solicitar saque";
    res.status(400).json({ error: message });
  }
});

/**
 * GET /api/wallet/withdrawals
 * Get withdrawal history.
 */
router.get("/withdrawals", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const status = req.query.status ? String(req.query.status) : undefined;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    let query: admin.firestore.Query = db
      .collection("withdrawals")
      .where("tenantId", "==", tenantId)
      .orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    const snap = await query.limit(50).get();

    const withdrawals = snap.docs.map((doc) => ({ id: doc.id, ...serializeTimestamps(doc.data()) }));

    res.json({ withdrawals });
  } catch (error) {
    functions.logger.error("Error fetching withdrawals", error);
    res.status(500).json({ error: "Erro ao buscar saques" });
  }
});

/**
 * PATCH /api/wallet/bank-account
 * Update bank account for withdrawals.
 */
router.patch("/bank-account", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const bankAccount = req.body;

  // Validate required fields
  const requiredFields = ["bankCode", "bankName", "branch", "accountNumber", "accountDigit", "holderName", "holderDocument"];
  for (const field of requiredFields) {
    if (!bankAccount[field]) {
      res.status(400).json({ error: `Campo obrigatório: ${field}` });
      return;
    }
  }

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Acesso restrito a vendedores" });
      return;
    }

    const db = admin.firestore();
    const walletRef = db.collection("wallets").doc(tenantId);
    const now = admin.firestore.Timestamp.now();

    const walletSnap = await walletRef.get();

    if (walletSnap.exists) {
      await walletRef.update({
        bankAccount: {
          bankCode: bankAccount.bankCode,
          bankName: bankAccount.bankName,
          branch: bankAccount.branch,
          branchDigit: bankAccount.branchDigit || null,
          accountNumber: bankAccount.accountNumber,
          accountDigit: bankAccount.accountDigit,
          accountType: bankAccount.accountType || "checking",
          holderName: bankAccount.holderName,
          holderDocument: bankAccount.holderDocument.replace(/\D/g, ""),
        },
        updatedAt: now,
      });
    } else {
      await walletRef.set({
        id: tenantId,
        tenantId,
        status: "active",
        balance: {
          available: 0,
          pending: 0,
          blocked: 0,
          total: 0,
        },
        bankAccount: {
          bankCode: bankAccount.bankCode,
          bankName: bankAccount.bankName,
          branch: bankAccount.branch,
          branchDigit: bankAccount.branchDigit || null,
          accountNumber: bankAccount.accountNumber,
          accountDigit: bankAccount.accountDigit,
          accountType: bankAccount.accountType || "checking",
          holderName: bankAccount.holderName,
          holderDocument: bankAccount.holderDocument.replace(/\D/g, ""),
        },
        gatewayProvider: "mercadopago",
        createdAt: now,
        updatedAt: now,
      });
    }

    const updatedDoc = await walletRef.get();
    res.json(serializeWallet(updatedDoc.data()!));
  } catch (error) {
    functions.logger.error("Error updating bank account", error);
    res.status(500).json({ error: "Erro ao atualizar conta bancária" });
  }
});

// ============================================================================
// Helpers
// ============================================================================

function serializeWallet(data: admin.firestore.DocumentData): Record<string, unknown> {
  return serializeTimestamps(data);
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
