import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Router, Request, Response } from "express";
import { config } from "../config";
import {
  AuthenticatedRequest,
  getTenantForUser,
  getSellerMpTokens,
  storeSellerMpTokens,
  removeSellerMpTokens,
} from "../middleware/auth";
import {
  buildOAuthUrl,
  exchangeOAuthCode,
  refreshOAuthToken,
} from "./client";

const router = Router();

/**
 * GET /api/mercadopago/oauth
 * Generate OAuth authorization URL or get connection status.
 *
 * Query params:
 *   action=url -> Generate OAuth URL
 *   (none)    -> Get connection status
 */
router.get("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Apenas vendedores podem conectar ao Mercado Pago" });
      return;
    }

    // Get connection status
    const db = admin.firestore();
    const tenantDoc = await db.collection("tenants").doc(tenantId).get();
    const tenantData = tenantDoc.data();
    const mpConnection = tenantData?.mpConnection;

    res.json({
      isConnected: mpConnection?.isConnected || false,
      mpUserId: mpConnection?.mpUserId || null,
      connectedAt: mpConnection?.connectedAt?.toDate()?.toISOString() || null,
    });
  } catch (error) {
    functions.logger.error("Error getting MP connection status", error);
    res.status(500).json({ error: "Erro ao verificar conexão" });
  }
});

/**
 * POST /api/mercadopago/oauth
 * Generate OAuth URL or exchange authorization code.
 *
 * Body:
 *   { action: 'url' }      -> Returns { url: '...' }
 *   { action: 'callback', code: '...' } -> Exchange code for tokens
 */
router.post("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;
  const { action, code } = req.body;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Apenas vendedores podem conectar ao Mercado Pago" });
      return;
    }

    if (action === "url") {
      // Validate required config before generating OAuth URL
      if (!config.mercadoPago.clientId || !config.mercadoPago.oauthRedirectUri) {
        functions.logger.error("Missing MP OAuth config", {
          hasClientId: !!config.mercadoPago.clientId,
          hasRedirectUri: !!config.mercadoPago.oauthRedirectUri,
        });
        res.status(500).json({
          error: "Configuração do Mercado Pago incompleta. Entre em contato com o suporte.",
        });
        return;
      }

      // Generate OAuth URL
      // Store state in Firestore for CSRF validation
      const state = `${tenantId}_${Date.now()}_${Math.random().toString(36).substring(2)}`;

      const db = admin.firestore();
      const expiresAt = admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 10 * 60 * 1000) // 10 min expiry
      );

      // Store in tenant's private collection (for POST callback validation)
      await db.collection("tenants").doc(tenantId).collection("private").doc("oauth_state").set({
        state,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
      });

      // Also store in top-level collection for GET callback lookup (browser flow)
      await db.collection("mp_oauth_states").doc(state).set({
        tenantId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt,
      });

      const oauthUrl = buildOAuthUrl(
        config.mercadoPago.clientId,
        config.mercadoPago.oauthRedirectUri,
        state
      );

      res.json({ url: oauthUrl });
      return;
    }

    if (action === "callback" && code) {
      const { state } = req.body;

      // Validate OAuth state to prevent CSRF attacks
      const db = admin.firestore();
      const stateDocRef = db
        .collection("tenants")
        .doc(tenantId)
        .collection("private")
        .doc("oauth_state");
      const stateDoc = await stateDocRef.get();

      if (!stateDoc.exists) {
        functions.logger.error("OAuth state not found - possible CSRF attack or expired state", { tenantId });
        res.status(400).json({ error: "Estado OAuth inválido ou expirado. Tente conectar novamente." });
        return;
      }

      const storedData = stateDoc.data()!;

      // Validate state matches (state is REQUIRED to prevent CSRF)
      if (!state || storedData.state !== state) {
        functions.logger.error("OAuth state mismatch - possible CSRF attack", {
          tenantId,
          expected: storedData.state,
          received: state,
        });
        await stateDocRef.delete(); // Clean up
        res.status(400).json({ error: "Estado OAuth inválido. Tente conectar novamente." });
        return;
      }

      // Validate state hasn't expired
      const expiresAt = storedData.expiresAt;
      if (expiresAt && expiresAt.toDate() < new Date()) {
        functions.logger.error("OAuth state expired", { tenantId });
        await stateDocRef.delete();
        res.status(400).json({ error: "Autorização expirada. Tente conectar novamente." });
        return;
      }

      // Delete state after validation to prevent replay attacks
      await stateDocRef.delete();

      // Exchange authorization code for tokens
      const tokens = await exchangeOAuthCode(
        config.mercadoPago.clientId,
        config.mercadoPago.clientSecret,
        code,
        config.mercadoPago.oauthRedirectUri
      );

      // Store tokens securely in Firestore
      await storeSellerMpTokens(tenantId, {
        accessToken: tokens.access_token,
        refreshToken: tokens.refresh_token,
        mpUserId: tokens.user_id,
        publicKey: tokens.public_key,
        expiresIn: tokens.expires_in,
      });

      functions.logger.info("Seller connected to MP", {
        tenantId,
        mpUserId: tokens.user_id,
      });

      res.json({
        isConnected: true,
        mpUserId: tokens.user_id,
        connectedAt: new Date().toISOString(),
      });
      return;
    }

    res.status(400).json({ error: "Ação inválida" });
  } catch (error) {
    functions.logger.error("Error in MP OAuth", error);
    res.status(500).json({ error: "Erro na autenticação com Mercado Pago" });
  }
});

/**
 * DELETE /api/mercadopago/oauth
 * Disconnect Mercado Pago account.
 */
router.delete("/", async (req: Request, res: Response): Promise<void> => {
  const authReq = req as AuthenticatedRequest;
  const uid = authReq.uid;

  try {
    const tenantId = await getTenantForUser(uid);
    if (!tenantId) {
      res.status(403).json({ error: "Apenas vendedores podem desconectar" });
      return;
    }

    await removeSellerMpTokens(tenantId);

    functions.logger.info("Seller disconnected from MP", { tenantId });
    res.json({ success: true });
  } catch (error) {
    functions.logger.error("Error disconnecting MP", error);
    res.status(500).json({ error: "Erro ao desconectar" });
  }
});

/**
 * Sanitize a string for safe HTML insertion.
 * Escapes &, <, >, ", and ' to prevent XSS.
 */
function escapeHtml(str: string): string {
  if (!str) return "";
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

/**
 * GET /api/mp-oauth-callback
 * OAuth callback handler (redirect URI for MP).
 * This endpoint is called by Mercado Pago after seller authorization.
 *
 * Performs the full token exchange server-side so the mobile app only needs
 * to poll for connection status (no WebView required).
 */
export async function handleOAuthCallback(req: Request, res: Response): Promise<void> {
  const code = req.query.code as string;
  const state = req.query.state as string;
  const error = req.query.error as string;

  if (error) {
    const safeError = escapeHtml(error);
    res.status(400).send(callbackHtml(
      "Erro na autorização",
      safeError,
      true,
    ));
    return;
  }

  if (!code || !state) {
    res.status(400).send(callbackHtml(
      "Dados incompletos",
      "Código de autorização ou estado ausente.",
      true,
    ));
    return;
  }

  try {
    const db = admin.firestore();

    // Look up tenantId from the top-level state index
    const stateDocRef = db.collection("mp_oauth_states").doc(state);
    const stateDoc = await stateDocRef.get();

    if (!stateDoc.exists) {
      res.status(400).send(callbackHtml(
        "Link expirado",
        "Esta autorização já foi usada ou expirou. Volte ao app e tente novamente.",
        true,
      ));
      return;
    }

    const stateData = stateDoc.data()!;
    const tenantId = stateData.tenantId as string;

    // Validate expiration
    if (stateData.expiresAt && stateData.expiresAt.toDate() < new Date()) {
      await stateDocRef.delete();
      res.status(400).send(callbackHtml(
        "Autorização expirada",
        "O tempo para autorizar expirou. Volte ao app e tente novamente.",
        true,
      ));
      return;
    }

    // Delete state documents to prevent replay attacks
    await stateDocRef.delete();
    await db.collection("tenants").doc(tenantId)
      .collection("private").doc("oauth_state").delete()
      .catch(() => {}); // Ignore if already deleted

    // Exchange authorization code for tokens
    const tokens = await exchangeOAuthCode(
      config.mercadoPago.clientId,
      config.mercadoPago.clientSecret,
      code,
      config.mercadoPago.oauthRedirectUri
    );

    // Store tokens securely
    await storeSellerMpTokens(tenantId, {
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
      mpUserId: tokens.user_id,
      publicKey: tokens.public_key,
      expiresIn: tokens.expires_in,
    });

    functions.logger.info("Seller connected to MP via browser OAuth", {
      tenantId,
      mpUserId: tokens.user_id,
    });

    res.send(callbackHtml(
      "Conta conectada!",
      "Sua conta do Mercado Pago foi conectada com sucesso. Volte ao aplicativo para continuar.",
      false,
    ));
  } catch (err) {
    functions.logger.error("Error in OAuth callback exchange", err);
    res.status(500).send(callbackHtml(
      "Erro ao conectar",
      "Ocorreu um erro ao processar a autorização. Volte ao app e tente novamente.",
      true,
    ));
  }
}

/**
 * Render a mobile-friendly HTML page for the OAuth callback result.
 */
function callbackHtml(title: string, message: string, isError: boolean): string {
  const safeTitle = escapeHtml(title);
  const safeMessage = escapeHtml(message);
  const color = isError ? "#E53935" : "#00A650";
  const icon = isError ? "&#10007;" : "&#10003;";
  const deepLinkStatus = isError ? "error" : "success";
  const deepLinkUrl = `nexmarket://mp-oauth-callback?status=${deepLinkStatus}`;

  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${safeTitle}</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      text-align: center; padding: 60px 24px; background: #fafafa; margin: 0; }
    .icon { font-size: 64px; color: ${color}; }
    h1 { font-size: 22px; color: #1a1a1a; margin: 16px 0 8px; }
    p { font-size: 16px; color: #666; line-height: 1.5; max-width: 320px; margin: 0 auto; }
    .hint { margin-top: 32px; font-size: 14px; color: #999; }
  </style>
</head>
<body>
  <div class="icon">${icon}</div>
  <h1>${safeTitle}</h1>
  <p>${safeMessage}</p>
  <p class="hint">Você já pode fechar esta janela.</p>
  <script>
    // Attempt to redirect back to the app via deep link
    window.location.href = "${deepLinkUrl}";
    // Fallback: if the redirect didn't work after 2s, the HTML is already visible
    setTimeout(function() {
      document.querySelector('.hint').textContent = 'Volte ao aplicativo para continuar.';
    }, 2000);
  </script>
</body>
</html>`;
}

/**
 * Helper to get a valid seller access token, refreshing if expired.
 * Uses a Firestore document lock to prevent concurrent refresh race conditions.
 * Two requests detecting expiration simultaneously could both try to refresh;
 * the second would fail because MP already rotated the refresh_token.
 */
export async function getValidSellerToken(tenantId: string): Promise<string> {
  const db = admin.firestore();
  const lockRef = db.doc(`token_refresh_locks/${tenantId}`);
  const bufferMs = 5 * 60 * 1000; // 5 minutes

  const tokens = await getSellerMpTokens(tenantId);

  if (!tokens) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vendedor não conectado ao Mercado Pago"
    );
  }

  // Token still valid? Return directly
  const now = new Date();
  if (tokens.expiresAt.getTime() - bufferMs > now.getTime()) {
    return tokens.accessToken;
  }

  // Token expired — try to acquire lock (create fails if already exists)
  try {
    await lockRef.create({ createdAt: admin.firestore.FieldValue.serverTimestamp() });
  } catch (_e) {
    // Another process is already refreshing — wait briefly and return the (hopefully fresh) token
    await new Promise((r) => setTimeout(r, 2000));
    const freshTokens = await getSellerMpTokens(tenantId);
    if (!freshTokens) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vendedor não conectado ao Mercado Pago"
      );
    }
    return freshTokens.accessToken;
  }

  try {
    // Re-read tokens to check if another process completed the refresh before we acquired the lock
    const freshTokens = await getSellerMpTokens(tenantId);
    if (!freshTokens) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Vendedor não conectado ao Mercado Pago"
      );
    }

    if (freshTokens.expiresAt.getTime() - bufferMs > now.getTime()) {
      // Another process already refreshed — return the updated token
      return freshTokens.accessToken;
    }

    // Perform the actual refresh
    functions.logger.info("Refreshing seller MP token", { tenantId });

    const refreshed = await refreshOAuthToken(
      config.mercadoPago.clientId,
      config.mercadoPago.clientSecret,
      freshTokens.refreshToken
    );

    await storeSellerMpTokens(tenantId, {
      accessToken: refreshed.access_token,
      refreshToken: refreshed.refresh_token,
      mpUserId: refreshed.user_id,
      publicKey: refreshed.public_key,
      expiresIn: refreshed.expires_in,
    });

    return refreshed.access_token;
  } finally {
    // Always release the lock
    await lockRef.delete().catch(() => {});
  }
}

export default router;
