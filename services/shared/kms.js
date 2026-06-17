const { KMSClient, EncryptCommand } = require("@aws-sdk/client-kms");

const kmsClient = new KMSClient({});

function maskSsn(rawValue) {
  const digitsOnly = String(rawValue || "").replace(/\D/g, "");

  if (digitsOnly.length !== 9) {
    throw new Error("SSN must contain exactly 9 digits");
  }

  return `***-**-${digitsOnly.slice(-4)}`;
}

async function encryptSensitiveValue(plaintext, context = {}) {
  const keyId = process.env.SENSITIVE_FIELDS_KMS_KEY_ID;

  if (!keyId) {
    throw new Error("Missing SENSITIVE_FIELDS_KMS_KEY_ID environment variable");
  }

  const response = await kmsClient.send(
    new EncryptCommand({
      KeyId: keyId,
      Plaintext: Buffer.from(String(plaintext), "utf8"),
      EncryptionContext: {
        environment: process.env.ENVIRONMENT || "dev",
        field: context.field || "sensitive",
        service: context.service || "event-driven-observability-platform",
      },
    }),
  );

  return {
    ciphertext: Buffer.from(response.CiphertextBlob).toString("base64"),
    encryptionVersion:
      process.env.SENSITIVE_FIELDS_ENCRYPTION_VERSION || "kms-v1",
  };
}

module.exports = {
  encryptSensitiveValue,
  maskSsn,
};
