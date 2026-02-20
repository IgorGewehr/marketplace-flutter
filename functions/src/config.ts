import * as functions from "firebase-functions";

// Firebase Functions automatically loads functions/.env on deploy.
// For local emulator, dotenv loads it from the file.
import * as dotenv from "dotenv";
dotenv.config();

export const config = {
  mercadoPago: {
    accessToken: process.env.MP_ACCESS_TOKEN || "",
    publicKey: process.env.MP_PUBLIC_KEY || "",
    clientId: process.env.MP_CLIENT_ID || "",
    clientSecret: process.env.MP_CLIENT_SECRET || "",
    webhookSecret: process.env.MP_WEBHOOK_SECRET || "",
    oauthRedirectUri: process.env.MP_OAUTH_REDIRECT_URI || "",
  },
  platform: {
    feePercentage: parseFloat(process.env.PLATFORM_FEE_PERCENTAGE || "5.0"),
    paymentHoldHours: parseInt(process.env.PAYMENT_HOLD_HOURS || "24", 10),
  },
};

// Validate required config on startup
export function validateConfig(): void {
  const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

  const required = [
    ["MP_ACCESS_TOKEN", config.mercadoPago.accessToken],
    ["MP_PUBLIC_KEY", config.mercadoPago.publicKey],
    ["MP_CLIENT_ID", config.mercadoPago.clientId],
    ["MP_CLIENT_SECRET", config.mercadoPago.clientSecret],
  ];

  for (const [name, value] of required) {
    if (!value) {
      if (isEmulator) {
        functions.logger.warn(`Missing required config: ${name}`);
      } else {
        functions.logger.error(`CRITICAL: Missing required config: ${name}. Add it to functions/.env`);
      }
    }
  }

  if (!config.mercadoPago.webhookSecret) {
    if (isEmulator) {
      functions.logger.warn("MP_WEBHOOK_SECRET not set - webhook signature validation disabled (OK for emulator)");
    } else {
      functions.logger.error(
        "CRITICAL: MP_WEBHOOK_SECRET is not configured! " +
        "Webhooks will be rejected in production. " +
        "Add MP_WEBHOOK_SECRET to functions/.env"
      );
    }
  }

  if (!config.mercadoPago.oauthRedirectUri) {
    functions.logger.warn("MP_OAUTH_REDIRECT_URI not set - seller OAuth connection will not work");
  }
}
