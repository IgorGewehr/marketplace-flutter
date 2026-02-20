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
      await db.collection("tenants").doc(tenantId).collection("private").doc("oauth_state").set({
        state,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 10 * 60 * 1000) // 10 min expiry
        ),
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
 * Returns a simple HTML page that the WebView can parse.
 */
export async function handleOAuthCallback(req: Request, res: Response): Promise<void> {
  const code = req.query.code as string;
  const state = req.query.state as string;
  const error = req.query.error as string;

  if (error) {
    const safeError = escapeHtml(error);
    res.status(400).send(`
      <html><body>
        <h1>Erro na autorização</h1>
        <p>${safeError}</p>
        <script>
          window.location.href = 'mp-oauth-callback?error=' + encodeURIComponent(${JSON.stringify(error)});
        </script>
      </body></html>
    `);
    return;
  }

  if (!code) {
    res.status(400).send("Missing authorization code");
    return;
  }

  // Redirect so the mobile WebView can intercept the callback URL.
  // Use a server-side 302 redirect instead of JS-based redirect for reliability.
  const redirectUrl = `/mp-oauth-callback?code=${encodeURIComponent(code)}&state=${encodeURIComponent(state || "")}`;
  res.redirect(302, redirectUrl);
}

/**
 * Helper to get a valid seller access token, refreshing if expired.
 */
export async function getValidSellerToken(tenantId: string): Promise<string> {
  const tokens = await getSellerMpTokens(tenantId);

  if (!tokens) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Vendedor não conectado ao Mercado Pago"
    );
  }

  // Check if token is expired (with 5 minute buffer)
  const now = new Date();
  const expiresAt = tokens.expiresAt;
  const bufferMs = 5 * 60 * 1000;

  if (expiresAt.getTime() - bufferMs <= now.getTime()) {
    functions.logger.info("Refreshing seller MP token", { tenantId });

    const refreshed = await refreshOAuthToken(
      config.mercadoPago.clientId,
      config.mercadoPago.clientSecret,
      tokens.refreshToken
    );

    await storeSellerMpTokens(tenantId, {
      accessToken: refreshed.access_token,
      refreshToken: refreshed.refresh_token,
      mpUserId: refreshed.user_id,
      publicKey: refreshed.public_key,
      expiresIn: refreshed.expires_in,
    });

    return refreshed.access_token;
  }

  return tokens.accessToken;
}

export default router;
