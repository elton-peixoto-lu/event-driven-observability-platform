const { SQSClient, SendMessageCommand } = require("@aws-sdk/client-sqs");
const { emitMetric } = require("../../shared/metrics");
const { createLogger } = require("../../shared/logger");
const { encryptSensitiveValue, maskSsn } = require("../../shared/kms");
const { upsertCustomerSensitiveData } = require("../../shared/supabase");
const { randomUUID } = require("crypto");

const REQUIRED_FIELDS = ["eventId", "eventName", "eventType", "payload"];
const REQUIRED_PAYLOAD_FIELDS = [
  "order_id",
  "customer_id",
  "amount",
  "currency",
];

function getPlaintextSsn(payload) {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  if (typeof payload.ssn === "string" && payload.ssn.trim() !== "") {
    return payload.ssn;
  }

  if (
    payload.sensitive &&
    typeof payload.sensitive === "object" &&
    typeof payload.sensitive.ssn === "string" &&
    payload.sensitive.ssn.trim() !== ""
  ) {
    return payload.sensitive.ssn;
  }

  return null;
}

function isValidSsnInput(value) {
  return String(value || "").replace(/\D/g, "").length === 9;
}

function normalizeCustomerId(value) {
  if (typeof value === "number" && Number.isInteger(value)) {
    return value;
  }

  if (typeof value === "string" && /^[0-9]+$/.test(value.trim())) {
    return Number(value.trim());
  }

  return null;
}

function buildSanitizedPayload(payload, ssnMasked) {
  const sanitizedPayload = {
    ...payload,
    sensitive: {
      ...(payload.sensitive && typeof payload.sensitive === "object"
        ? payload.sensitive
        : {}),
      ssn_masked: ssnMasked,
      ssn_ref: payload.customer_id,
    },
  };

  delete sanitizedPayload.ssn;
  delete sanitizedPayload.sensitive.ssn;

  return sanitizedPayload;
}

function validate(body) {
  const missing = [];

  for (const field of REQUIRED_FIELDS) {
    if (body[field] == null) missing.push(field);
  }

  if (body.payload != null) {
    for (const field of REQUIRED_PAYLOAD_FIELDS) {
      if (body.payload[field] == null) missing.push(`payload.${field}`);
    }
  }

  return missing;
}

const sqsClient = new SQSClient({
  region: process.env.AWS_REGION || "us-east-2",
});

exports.handler = async (event, context) => {
  const correlationId =
    event.headers?.["x-correlation-id"] ||
    event.headers?.["X-Correlation-ID"] ||
    randomUUID();

  const log = createLogger({
    service: "ingestion",
    correlationId,
    awsRequestId: context.awsRequestId,
  });

  try {
    const body = JSON.parse(event.body);

    const missingFields = validate(body);
    if (missingFields.length > 0) {
      log.warn({ reason: "SchemaViolation", missingFields });
      emitMetric({
        namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
        metricName: "EventRejected",
        service: "ingestion",
      });
      return {
        statusCode: 400,
        headers: { "x-correlation-id": correlationId },
        body: JSON.stringify({
          message: "Contract violation",
          missingFields,
          correlationId,
        }),
      };
    }

    const plaintextSsn = getPlaintextSsn(body.payload);
    const normalizedCustomerId = normalizeCustomerId(body.payload.customer_id);
    if (plaintextSsn && !isValidSsnInput(plaintextSsn)) {
      log.warn({ reason: "SchemaViolation", invalidField: "payload.sensitive.ssn" });
      emitMetric({
        namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
        metricName: "EventRejected",
        service: "ingestion",
      });
      return {
        statusCode: 400,
        headers: { "x-correlation-id": correlationId },
        body: JSON.stringify({
          message: "Contract violation",
          invalidField: "payload.sensitive.ssn",
          correlationId,
        }),
      };
    }

    if (plaintextSsn && normalizedCustomerId == null) {
      log.warn({ reason: "SchemaViolation", invalidField: "payload.customer_id" });
      emitMetric({
        namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
        metricName: "EventRejected",
        service: "ingestion",
      });
      return {
        statusCode: 400,
        headers: { "x-correlation-id": correlationId },
        body: JSON.stringify({
          message: "Contract violation",
          invalidField: "payload.customer_id",
          correlationId,
        }),
      };
    }

    // Ingestion failure
    if (body.forceIngestionFailure) {
      throw new Error("Ingestion Failure");
    }

    let sanitizedPayload = {
      ...body.payload,
      ...(normalizedCustomerId != null
        ? { customer_id: normalizedCustomerId }
        : {}),
    };
    let hasSensitiveData = false;

    if (plaintextSsn) {
      const ssnMasked = maskSsn(plaintextSsn);
      const { ciphertext, encryptionVersion } = await encryptSensitiveValue(
        plaintextSsn,
        {
          field: "ssn",
          service: "ingestion",
        },
      );

      await upsertCustomerSensitiveData({
        customerId: normalizedCustomerId,
        ssnMasked,
        ssnEncrypted: ciphertext,
        encryptionVersion,
      });

      sanitizedPayload = buildSanitizedPayload(sanitizedPayload, ssnMasked);
      hasSensitiveData = true;
    }

    const normalizedEvent = {
      eventId: body.eventId,
      eventName: body.eventName,
      eventType: body.eventType,
      payload: sanitizedPayload,
      failTransient: body.failTransient === true,
      _metadata: {
        correlationId,
        awsRequestId: context.awsRequestId,
        receivedAt: new Date().toISOString(),
        sourceIp: event.requestContext?.http?.sourceIp ?? null,
        userAgent: event.headers?.["user-agent"] ?? null,
      },
    };

    await sqsClient.send(
      new SendMessageCommand({
        QueueUrl: process.env.SQS_QUEUE_URL,
        MessageBody: JSON.stringify(normalizedEvent),
      }),
    );

    log.info({
      eventId: body.eventId,
      eventType: body.eventType,
      hasSensitiveData,
      message: "Event ingested successfully",
    });

    emitMetric({
      namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
      metricName: "EventIngested",
      service: "ingestion",
    });

    return {
      statusCode: 202,
      headers: { "x-correlation-id": correlationId },
      body: JSON.stringify({
        message: "Event received and queued for processing",
        correlationId,
        eventId: body.eventId,
      }),
    };
  } catch (error) {
    log.error({ error: error.message });
    emitMetric({
      namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
      metricName: "EventFailed",
      service: "ingestion",
    });
    return {
      statusCode: 500,
      headers: { "x-correlation-id": correlationId },
      body: JSON.stringify({ message: "Internal Server Error", correlationId }),
    };
  }
};
