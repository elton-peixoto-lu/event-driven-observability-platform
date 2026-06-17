const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require("@aws-sdk/client-secrets-manager");

const secretsClient = new SecretsManagerClient({});
const configCache = new Map();

function getSecretArn() {
  const secretArn = process.env.SUPABASE_SECRET_ARN;

  if (!secretArn) {
    throw new Error("Missing SUPABASE_SECRET_ARN environment variable");
  }

  return secretArn;
}

async function getSupabaseConfig() {
  const secretArn = getSecretArn();

  if (!configCache.has(secretArn)) {
    configCache.set(
      secretArn,
      (async () => {
        const response = await secretsClient.send(
          new GetSecretValueCommand({
            SecretId: secretArn,
          }),
        );

        if (!response.SecretString) {
          throw new Error("Supabase secret is missing SecretString");
        }

        const parsed = JSON.parse(response.SecretString);
        const requiredKeys = [
          "SUPABASE_REST_URL",
          "SUPABASE_DATABASE",
          "SUPABASE_SERVICE_ROLE_KEY",
        ];

        for (const key of requiredKeys) {
          if (!parsed[key]) {
            throw new Error(`Supabase secret is missing ${key}`);
          }
        }

        return {
          restUrl: String(parsed.SUPABASE_REST_URL).replace(/\/+$/, ""),
          database: parsed.SUPABASE_DATABASE,
          serviceRoleKey: parsed.SUPABASE_SERVICE_ROLE_KEY,
          fallbackDatabase: "public",
        };
      })(),
    );
  }

  return configCache.get(secretArn);
}

function buildHeaders({
  config,
  profileHeaderName,
  body,
  schemaOverride,
  includeProfileHeader = true,
  method,
}) {
  const headers = {
    apikey: config.serviceRoleKey,
    Authorization: `Bearer ${config.serviceRoleKey}`,
  };

  if (includeProfileHeader) {
    headers[profileHeaderName] = schemaOverride || config.database;
  }

  if (body !== undefined) {
    headers["Content-Type"] = "application/json";
  }

  if (method === "POST") {
    headers.Prefer = "resolution=merge-duplicates,return=minimal";
  }

  return headers;
}

async function performRequest({ url, method, headers, body }) {
  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const text = await response.text();
  const parsedBody = text ? JSON.parse(text) : null;

  return {
    ok: response.ok,
    status: response.status,
    body: parsedBody,
  };
}

function isInvalidSchemaResponse(result) {
  return (
    result.status === 406 &&
    result.body &&
    result.body.code === "PGRST106"
  );
}

async function supabaseRequest({
  method,
  path,
  query,
  body,
  profileHeaderName = "Content-Profile",
}) {
  const config = await getSupabaseConfig();
  const url = new URL(path, `${config.restUrl}/`);

  if (query) {
    for (const [key, value] of Object.entries(query)) {
      url.searchParams.set(key, value);
    }
  }

  const primaryAttempt = await performRequest({
    url,
    method,
    headers: buildHeaders({
      config,
      profileHeaderName,
      body,
      method,
    }),
    body,
  });

  let finalResult = primaryAttempt;

  if (
    isInvalidSchemaResponse(primaryAttempt) &&
    config.database !== config.fallbackDatabase
  ) {
    finalResult = await performRequest({
      url,
      method,
      headers: buildHeaders({
        config,
        profileHeaderName,
        body,
        method,
        schemaOverride: config.fallbackDatabase,
      }),
      body,
    });
  }

  if (!finalResult.ok) {
    throw new Error(
      `Supabase request failed with ${finalResult.status}: ${JSON.stringify(finalResult.body)}`,
    );
  }

  if (finalResult.status === 204) {
    return null;
  }

  return finalResult.body;
}

async function upsertCustomerSensitiveData({
  customerId,
  ssnMasked,
  ssnEncrypted,
  encryptionVersion,
}) {
  const timestamp = new Date().toISOString();

  await supabaseRequest({
    method: "POST",
    path: "orders",
    query: {
      on_conflict: "customer_id",
    },
    body: [
      {
        customer_id: customerId,
        ssn_masked: ssnMasked,
        ssn_encrypted: ssnEncrypted,
        encryption_version: encryptionVersion,
        created_at: timestamp,
        updated_at: timestamp,
      },
    ],
    profileHeaderName: "Content-Profile",
  });
}

async function assertCustomerSensitiveDataExists(customerId) {
  const rows = await supabaseRequest({
    method: "GET",
    path: "orders",
    query: {
      select: "customer_id",
      customer_id: `eq.${customerId}`,
      limit: "1",
    },
    profileHeaderName: "Accept-Profile",
  });

  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error(
      `Missing orders row for customer_id ${customerId}`,
    );
  }
}

module.exports = {
  assertCustomerSensitiveDataExists,
  getSupabaseConfig,
  upsertCustomerSensitiveData,
};
