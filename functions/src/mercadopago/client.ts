import * as functions from "firebase-functions";

const MP_API_BASE = "https://api.mercadopago.com";

interface MpRequestOptions {
  method: "GET" | "POST" | "PUT" | "DELETE";
  path: string;
  body?: Record<string, unknown>;
  accessToken: string;
  idempotencyKey?: string;
}

interface MpPaymentRequest {
  transaction_amount: number;
  description: string;
  payment_method_id?: string;
  payer: {
    email: string;
    first_name?: string;
    last_name?: string;
    identification?: {
      type: string;
      number: string;
    };
  };
  token?: string;
  installments?: number;
  notification_url?: string;
  external_reference?: string;
  application_fee?: number;
  money_release_days?: number;
  metadata?: Record<string, unknown>;
  date_of_expiration?: string;
  three_d_secure_mode?: string;
  binary_mode?: boolean;
}

interface MpPaymentResponse {
  id: number;
  status: string;
  status_detail: string;
  transaction_amount: number;
  currency_id: string;
  payment_method_id: string;
  payment_type_id: string;
  date_created: string;
  date_approved: string | null;
  point_of_interaction?: {
    transaction_data?: {
      qr_code?: string;
      qr_code_base64?: string;
      ticket_url?: string;
    };
  };
  external_reference?: string;
  metadata?: Record<string, unknown>;
  fee_details?: Array<{
    type: string;
    amount: number;
    fee_payer: string;
  }>;
}

interface MpOAuthTokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  scope: string;
  user_id: number;
  refresh_token: string;
  public_key: string;
  live_mode: boolean;
}

interface MpDisbursementRequest {
  amount: number;
  external_reference?: string;
  collector_id?: number;
}

/**
 * Generic Mercado Pago API client.
 * All calls go through this to ensure consistent error handling and logging.
 */
async function mpRequest<T>(options: MpRequestOptions): Promise<T> {
  const url = `${MP_API_BASE}${options.path}`;
  const headers: Record<string, string> = {
    "Authorization": `Bearer ${options.accessToken}`,
    "Content-Type": "application/json",
    "Accept": "application/json",
  };

  if (options.idempotencyKey) {
    headers["X-Idempotency-Key"] = options.idempotencyKey;
  }

  const fetchOptions: RequestInit = {
    method: options.method,
    headers,
  };

  if (options.body && (options.method === "POST" || options.method === "PUT")) {
    fetchOptions.body = JSON.stringify(options.body);
  }

  functions.logger.info(`MP API ${options.method} ${options.path}`);

  const response = await fetch(url, fetchOptions);
  const responseBody = await response.text();

  let parsed: unknown;
  try {
    parsed = JSON.parse(responseBody);
  } catch {
    parsed = responseBody;
  }

  if (!response.ok) {
    functions.logger.error("MP API Error", {
      status: response.status,
      path: options.path,
      body: parsed,
    });
    throw new functions.https.HttpsError(
      "internal",
      `Mercado Pago API error: ${response.status}`,
      parsed as Record<string, unknown>
    );
  }

  return parsed as T;
}

// ============================================================================
// Payment Methods
// ============================================================================

/**
 * Create a payment via Mercado Pago API.
 * Uses the seller's access_token (from OAuth) for marketplace split payments.
 */
export async function createPayment(
  payment: MpPaymentRequest,
  sellerAccessToken: string,
  idempotencyKey: string
): Promise<MpPaymentResponse> {
  return mpRequest<MpPaymentResponse>({
    method: "POST",
    path: "/v1/payments",
    body: payment as unknown as Record<string, unknown>,
    accessToken: sellerAccessToken,
    idempotencyKey,
  });
}

/**
 * Get payment details by ID.
 */
export async function getPayment(
  paymentId: string | number,
  accessToken: string
): Promise<MpPaymentResponse> {
  return mpRequest<MpPaymentResponse>({
    method: "GET",
    path: `/v1/payments/${paymentId}`,
    accessToken,
  });
}

/**
 * Refund a payment (full).
 */
export async function refundPayment(
  paymentId: string | number,
  accessToken: string,
  idempotencyKey: string
): Promise<Record<string, unknown>> {
  return mpRequest<Record<string, unknown>>({
    method: "POST",
    path: `/v1/payments/${paymentId}/refunds`,
    accessToken,
    idempotencyKey,
  });
}

// ============================================================================
// OAuth Methods
// ============================================================================

/**
 * Build the OAuth authorization URL for seller connection.
 */
export function buildOAuthUrl(clientId: string, redirectUri: string, state: string): string {
  const params = new URLSearchParams({
    client_id: clientId,
    response_type: "code",
    platform_id: "mp",
    redirect_uri: redirectUri,
    state: state,
  });
  return `https://auth.mercadopago.com.br/authorization?${params.toString()}`;
}

/**
 * Exchange an authorization code for access tokens.
 */
export async function exchangeOAuthCode(
  clientId: string,
  clientSecret: string,
  code: string,
  redirectUri: string
): Promise<MpOAuthTokenResponse> {
  const url = `${MP_API_BASE}/oauth/token`;

  const body = {
    client_secret: clientSecret,
    client_id: clientId,
    grant_type: "authorization_code",
    code: code,
    redirect_uri: redirectUri,
  };

  functions.logger.info("Exchanging OAuth code for tokens");

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: JSON.stringify(body),
  });

  const responseBody = await response.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(responseBody);
  } catch {
    parsed = responseBody;
  }

  if (!response.ok) {
    functions.logger.error("OAuth token exchange failed", {
      status: response.status,
      body: parsed,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Failed to exchange OAuth code",
      parsed as Record<string, unknown>
    );
  }

  return parsed as MpOAuthTokenResponse;
}

/**
 * Refresh an OAuth access token using refresh_token.
 */
export async function refreshOAuthToken(
  clientId: string,
  clientSecret: string,
  refreshToken: string
): Promise<MpOAuthTokenResponse> {
  const url = `${MP_API_BASE}/oauth/token`;

  const body = {
    client_secret: clientSecret,
    client_id: clientId,
    grant_type: "refresh_token",
    refresh_token: refreshToken,
  };

  functions.logger.info("Refreshing OAuth token");

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: JSON.stringify(body),
  });

  const responseBody = await response.text();
  let parsed: unknown;
  try {
    parsed = JSON.parse(responseBody);
  } catch {
    parsed = responseBody;
  }

  if (!response.ok) {
    functions.logger.error("OAuth token refresh failed", {
      status: response.status,
      body: parsed,
    });
    throw new functions.https.HttpsError(
      "internal",
      "Failed to refresh OAuth token",
      parsed as Record<string, unknown>
    );
  }

  return parsed as MpOAuthTokenResponse;
}

// ============================================================================
// Disbursement / Transfer Methods
// ============================================================================

/**
 * Send money to a bank account via Mercado Pago (for seller withdrawals).
 * Uses the /v1/transaction_orders endpoint for bank transfers.
 *
 * NOTE: The correct MP API path for bank transfers is /v1/transaction_orders.
 * The previously used /v1/disbursements path does not exist in the MP API and
 * would cause all withdrawal attempts to fail with a 404.
 */
export async function createBankTransfer(
  accessToken: string,
  amount: number,
  bankAccountData: {
    bank_id: string;
    type: string; // "checking" | "savings"
    number: string;
    holder_name: string;
    holder_document: string;
  },
  externalReference: string,
  idempotencyKey: string
): Promise<Record<string, unknown>> {
  return mpRequest<Record<string, unknown>>({
    method: "POST",
    path: "/v1/transaction_orders",
    body: {
      amount,
      external_reference: externalReference,
      bank_transfer: {
        bank_account: bankAccountData,
      },
    },
    accessToken,
    idempotencyKey,
  });
}

// ============================================================================
// Webhook Signature Validation
// ============================================================================

/**
 * Validate Mercado Pago webhook signature.
 * See: https://www.mercadopago.com.br/developers/pt/docs/your-integrations/notifications/webhooks
 */
export function validateWebhookSignature(
  xSignature: string,
  xRequestId: string,
  dataId: string,
  secret: string
): boolean {
  if (!secret) {
    functions.logger.error("Webhook secret not configured - cannot validate signature");
    return false;
  }

  if (!xSignature) {
    functions.logger.error("Missing x-signature header in webhook request");
    return false;
  }

  try {
    // Parse ts and v1 from x-signature header
    const parts = xSignature.split(",");
    let ts = "";
    let hash = "";

    for (const part of parts) {
      const [key, value] = part.trim().split("=");
      if (key === "ts") ts = value;
      if (key === "v1") hash = value;
    }

    if (!ts || !hash) {
      functions.logger.error("Invalid x-signature format");
      return false;
    }

    // Build the validation template
    const template = `id:${dataId};request-id:${xRequestId};ts:${ts};`;

    // Calculate HMAC-SHA256
    const crypto = require("crypto");
    const computedHash = crypto
      .createHmac("sha256", secret)
      .update(template)
      .digest("hex");

    return crypto.timingSafeEqual(
      Buffer.from(hash, "hex"),
      Buffer.from(computedHash, "hex")
    );
  } catch (error) {
    functions.logger.error("Webhook signature validation error", error);
    return false;
  }
}

export { mpRequest };
export type {
  MpRequestOptions,
  MpPaymentRequest,
  MpPaymentResponse,
  MpOAuthTokenResponse,
  MpDisbursementRequest,
};
