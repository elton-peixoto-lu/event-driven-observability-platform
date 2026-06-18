"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { loadWithMocks } = require("../helpers/load-with-mocks");

function createIngestionHandler(overrides = {}) {
  const sendCalls = [];
  const metricCalls = [];
  const loggerCalls = [];
  const upsertCalls = [];
  const encryptCalls = [];

  class MockSendMessageCommand {
    constructor(input) {
      this.input = input;
    }
  }

  class MockSqsClient {
    async send(command) {
      sendCalls.push(command.input);
      return { MessageId: "msg-1" };
    }
  }

  const handlerModule = loadWithMocks(
    "../../services/ingestion/src/handler.js",
    {
      "@aws-sdk/client-sqs": {
        SQSClient: MockSqsClient,
        SendMessageCommand: MockSendMessageCommand,
      },
      "../../shared/metrics": {
        emitMetric: (metric) => metricCalls.push(metric),
      },
      "../../shared/logger": {
        createLogger: () => ({
          info: (fields) => loggerCalls.push({ level: "INFO", fields }),
          warn: (fields) => loggerCalls.push({ level: "WARN", fields }),
          error: (fields) => loggerCalls.push({ level: "ERROR", fields }),
        }),
      },
      "../../shared/kms": {
        maskSsn: (ssn) => {
          const digits = String(ssn).replace(/\D/g, "");
          return `***-**-${digits.slice(-4)}`;
        },
        encryptSensitiveValue: async (plaintext, context) => {
          encryptCalls.push({ plaintext, context });
          return {
            ciphertext: "ciphertext-base64",
            encryptionVersion: "kms-v1",
          };
        },
      },
      "../../shared/supabase": {
        upsertCustomerSensitiveData: async (payload) => {
          upsertCalls.push(payload);
        },
      },
      crypto: {
        randomUUID: () => "uuid-from-test",
      },
      ...overrides.mocks,
    },
  );

  return {
    handler: handlerModule.handler,
    sendCalls,
    metricCalls,
    loggerCalls,
    upsertCalls,
    encryptCalls,
  };
}

test("ingestion queues sanitized event and persists encrypted SSN metadata", async () => {
  process.env.SQS_QUEUE_URL = "https://sqs.example/orders";
  process.env.METRICS_NAMESPACE = "ObservabilityPlatform";

  const {
    handler,
    sendCalls,
    metricCalls,
    upsertCalls,
    encryptCalls,
    loggerCalls,
  } = createIngestionHandler();

  const response = await handler(
    {
      headers: { "x-correlation-id": "corr-123", "user-agent": "node-test" },
      requestContext: {
        http: {
          sourceIp: "127.0.0.1",
        },
      },
      body: JSON.stringify({
        eventId: "evt-1",
        eventName: "Order Created",
        eventType: "OrderCreated",
        payload: {
          order_id: "order-1",
          customer_id: "1001",
          amount: 149.9,
          currency: "USD",
          sensitive: {
            ssn: "123-45-6789",
          },
        },
      }),
    },
    { awsRequestId: "aws-req-1" },
  );

  assert.equal(response.statusCode, 202);
  assert.equal(sendCalls.length, 1);
  assert.equal(upsertCalls.length, 1);
  assert.equal(encryptCalls.length, 1);
  assert.equal(metricCalls[0].metricName, "EventIngested");
  assert.equal(loggerCalls[0].fields.hasSensitiveData, true);

  const queuedEvent = JSON.parse(sendCalls[0].MessageBody);
  assert.equal(queuedEvent.payload.customer_id, 1001);
  assert.equal(queuedEvent.payload.sensitive.ssn_masked, "***-**-6789");
  assert.equal(queuedEvent.payload.sensitive.ssn_ref, 1001);
  assert.equal(queuedEvent.payload.sensitive.ssn, undefined);
  assert.equal(queuedEvent.payload.ssn, undefined);

  assert.deepEqual(upsertCalls[0], {
    customerId: 1001,
    ssnMasked: "***-**-6789",
    ssnEncrypted: "ciphertext-base64",
    encryptionVersion: "kms-v1",
  });
});

test("ingestion rejects invalid payload before publishing to SQS", async () => {
  process.env.SQS_QUEUE_URL = "https://sqs.example/orders";

  const { handler, sendCalls, metricCalls, loggerCalls } =
    createIngestionHandler();

  const response = await handler(
    {
      headers: {},
      body: JSON.stringify({
        eventId: "evt-2",
        eventName: "Order Created",
        eventType: "OrderCreated",
        payload: {
          order_id: "order-2",
          amount: 149.9,
          currency: "USD",
        },
      }),
    },
    { awsRequestId: "aws-req-2" },
  );

  assert.equal(response.statusCode, 400);
  assert.equal(sendCalls.length, 0);
  assert.equal(metricCalls[0].metricName, "EventRejected");
  assert.deepEqual(loggerCalls[0].fields.missingFields, ["payload.customer_id"]);
});
