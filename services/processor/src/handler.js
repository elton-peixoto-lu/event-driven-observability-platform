const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  TransactWriteCommand,
} = require("@aws-sdk/lib-dynamodb");
const { emitMetric } = require("../../shared/metrics");
const { createLogger } = require("../../shared/logger");

const client = new DynamoDBClient({});
const dynamoDb = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.IDEMPOTENCY_TABLE_NAME;
const ORDERS_TABLE_NAME = process.env.ORDERS_TABLE_NAME;

const REQUIRED_FIELDS = ["eventId", "eventName", "eventType", "payload"];

function validateNormalizedEvent(body) {
  const missing = [];

  for (const field of REQUIRED_FIELDS) {
    if (body[field] == null) missing.push(field);
  }

  if (body.payload != null && typeof body.payload !== "object") {
    missing.push("payload (must be object)");
  }

  return missing;
}

async function persistEventTransaction({
  eventId,
  eventName,
  eventType,
  payload,
}) {
  const expiresAt = Math.floor(Date.now() / 1000) + 28 * 60 * 60;
  const processedAt = new Date().toISOString();

  await dynamoDb.send(
    new TransactWriteCommand({
      TransactItems: [
        {
          Put: {
            TableName: TABLE_NAME,
            Item: { eventId, expiresAt },
            ConditionExpression: "attribute_not_exists(eventId)",
          },
        },
        {
          Put: {
            TableName: ORDERS_TABLE_NAME,
            Item: {
              eventId,
              eventName,
              eventType,
              orderId: payload.order_id,
              customerId: payload.customer_id,
              amount: payload.amount,
              currency: payload.currency,
              processedAt,
            },
          },
        },
      ],
    }),
  );
}

exports.handler = async (event) => {
  const failures = [];

  for (const record of event.Records) {
    const messageId = record.messageId;
    let correlationId = null;

    try {
      const body = JSON.parse(record.body);
      correlationId = body._metadata?.correlationId ?? null;

      const log = createLogger({
        service: "processor",
        correlationId,
        messageId,
      });

      const missingFields = validateNormalizedEvent(body);
      if (missingFields.length > 0) {
        log.warn({ reason: "SchemaViolation", missingFields });

        emitMetric({
          namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
          metricName: "EventRejected",
          service: "processor",
        });
        continue;
      }

      const { eventId, eventName, eventType, payload } = body;

      // Transient failure
      if (body.failTransient) {
        throw new Error("Transient processing error");
      }

      try {
        await persistEventTransaction(body);

        emitMetric({
          namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
          metricName: "EventProcessed",
          service: "processor",
        });

        log.info({ eventId, eventType, message: "Processed successfully" });
      } catch (err) {
        if (
          err.name === "TransactionCanceledException" &&
          err.CancellationReasons?.[0]?.Code === "ConditionalCheckFailed"
        ) {
          log.info({
            eventId,
            message: "Idempotency: Duplicated Message ignored",
          });
          emitMetric({
            namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
            metricName: "EventDuplicated",
            service: "processor",
          });
          continue;
        }
        throw err;
      }
    } catch (err) {
      const log = createLogger({
        service: "processor",
        correlationId,
        messageId,
      });
      log.error({ error: err.message });

      emitMetric({
        namespace: process.env.METRICS_NAMESPACE || "ObservabilityPlatform",
        metricName: "EventRetried",
        service: "processor",
      });

      failures.push({
        itemIdentifier: messageId,
      });
    }
  }

  return {
    batchItemFailures: failures,
  };
};
