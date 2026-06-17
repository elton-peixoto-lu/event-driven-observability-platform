const REDACTED_VALUE = "[REDACTED]";
const SENSITIVE_KEY_PARTS = [
  "supabase_service_role_key",
  "service_role",
  "apikey",
  "authorization",
  "token",
  "secret",
];

function shouldRedactKey(key) {
  const normalizedKey = String(key).toLowerCase();
  return SENSITIVE_KEY_PARTS.some((part) => normalizedKey.includes(part));
}

function redactValue(value, seen = new WeakSet()) {
  if (value == null) {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map((item) => redactValue(item, seen));
  }

  if (typeof value !== "object") {
    return value;
  }

  if (seen.has(value)) {
    return "[Circular]";
  }

  seen.add(value);

  return Object.fromEntries(
    Object.entries(value).map(([key, nestedValue]) => [
      key,
      shouldRedactKey(key) ? REDACTED_VALUE : redactValue(nestedValue, seen),
    ]),
  );
}

function createLogger(baseContext = {}) {
  function write(level, fields) {
    console.log(
      JSON.stringify({
        level,
        timestamp: new Date().toISOString(),
        ...redactValue(baseContext),
        ...redactValue(fields ?? {}),
      }),
    );
  }

  return {
    info: (fields) => write("INFO", fields),
    warn: (fields) => write("WARN", fields),
    error: (fields) => write("ERROR", fields),
  };
}

module.exports = { createLogger };
