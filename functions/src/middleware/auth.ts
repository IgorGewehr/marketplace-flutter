import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { Request, Response, NextFunction } from "express";

export interface AuthenticatedRequest extends Request {
  uid: string;
  userRecord?: admin.auth.UserRecord;
}

/**
 * Express middleware to verify Firebase Auth token.
 * Extracts uid and attaches it to the request object.
 */
export async function verifyAuth(
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing or invalid Authorization header" });
    return;
  }

  const idToken = authHeader.split("Bearer ")[1];

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    (req as AuthenticatedRequest).uid = decodedToken.uid;
    next();
  } catch (error) {
    functions.logger.error("Auth verification failed", error);
    res.status(401).json({ error: "Invalid or expired token" });
    return;
  }
}

/**
 * Get the tenant (seller) ID for a user.
 * Looks up the user document in Firestore to find their tenant.
 */
export async function getTenantForUser(uid: string): Promise<string | null> {
  const db = admin.firestore();
  const userDoc = await db.collection("users").doc(uid).get();

  if (!userDoc.exists) return null;

  const userData = userDoc.data();
  return userData?.tenantId || null;
}

/**
 * Get seller's Mercado Pago OAuth tokens from Firestore.
 * Tokens are stored in tenants/{tenantId}/private/mp_oauth
 */
export async function getSellerMpTokens(tenantId: string): Promise<{
  accessToken: string;
  refreshToken: string;
  mpUserId: number;
  publicKey: string;
  expiresAt: Date;
} | null> {
  const db = admin.firestore();
  const tokenDoc = await db
    .collection("tenants")
    .doc(tenantId)
    .collection("private")
    .doc("mp_oauth")
    .get();

  if (!tokenDoc.exists) return null;

  const data = tokenDoc.data();
  if (!data) return null;

  return {
    accessToken: data.accessToken,
    refreshToken: data.refreshToken,
    mpUserId: data.mpUserId,
    publicKey: data.publicKey,
    expiresAt: data.expiresAt?.toDate() || new Date(0),
  };
}

/**
 * Store seller's Mercado Pago OAuth tokens in Firestore.
 */
export async function storeSellerMpTokens(
  tenantId: string,
  tokens: {
    accessToken: string;
    refreshToken: string;
    mpUserId: number;
    publicKey: string;
    expiresIn: number;
  }
): Promise<void> {
  const db = admin.firestore();
  const expiresAt = new Date(Date.now() + tokens.expiresIn * 1000);

  await db
    .collection("tenants")
    .doc(tenantId)
    .collection("private")
    .doc("mp_oauth")
    .set(
      {
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        mpUserId: tokens.mpUserId,
        publicKey: tokens.publicKey,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  // Also update the tenant's public MP connection status
  await db.collection("tenants").doc(tenantId).update({
    "mpConnection.isConnected": true,
    "mpConnection.mpUserId": tokens.mpUserId,
    "mpConnection.connectedAt": admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Remove seller's Mercado Pago OAuth tokens.
 */
export async function removeSellerMpTokens(tenantId: string): Promise<void> {
  const db = admin.firestore();

  await db
    .collection("tenants")
    .doc(tenantId)
    .collection("private")
    .doc("mp_oauth")
    .delete();

  await db.collection("tenants").doc(tenantId).update({
    "mpConnection.isConnected": false,
    "mpConnection.mpUserId": admin.firestore.FieldValue.delete(),
    "mpConnection.connectedAt": admin.firestore.FieldValue.delete(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
