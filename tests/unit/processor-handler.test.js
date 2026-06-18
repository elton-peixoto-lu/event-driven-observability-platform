"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { loadWithMocks } = require("../helpers/load-with-mocks");

function createProcessorHandler(options = {}) {
  const sendCalls = [];
  const metricCalls = [];
  const loggerCalls = [];
  const supabaseChecks = [];

  class MockTransactWriteCommand {
    constructor(input) {
      this.input = input;
    }
  }

  class MockDynamoDocumentClient {
    async send(command) {
      sendCalls.push(command.input);

      if (options.transactionError) {
        throw options.transactionError;
      }

      return {};
    }
  }

  const handlerModule = loadWithMocks(
    "../../services/processor/src/handler.js",
    {
      "@aws-sdk/client-dynamodb": {
        DynamoDBClient: class MockDynamoDbClient {},
      },
      "@aws-sdk/lib-dynamodb": {
        DynamoDBDocumentClient: {
          from: () => new MockDynamoDocumentClient(),
        },
        TransactWriteCommand: MockTransactWriteCommand,
      },
      "../../shared/metrics": {
        emitMetric: (metric) => metricCalls.push(metric),
      },
      "../../shared/logger": {
        createLogger: ({ correlationId, messageId }) => ({
          info: (fields) =>
            loggerCalls.push({
              level: "INFO",
              correlationId,
              messageId,
              fields,
            }),
          warn: (fields) =>
            loggerCalls.push({
              level: "WARN",
              correlationId,
              messageId,
              fields,
            }),
          error: (fields) =>
            loggerCalls.push({
              level: "ERROR",
              correlationId,
              messageId,
              fields,
            }),
        }),
      },
      "../../shared/supabase": {
        getSupabaseConfig: async () => ({
          restUrl: "https://example.supabase.co/rest/v1",
          database: "orders",
        }),
        assertCustomerSensitiveDataExists: async (customerId) => {
          supabaseChecks.push(customerId);

          if (options.supabaseError) {
            throw options.supabaseError;
          }
        },
      },
    },
  );

  return {
    handler: handlerModule.handler,
    sendCalls,
    metricCalls,
    loggerCalls,
    supabaseChecks,
  };
}

test("processor treats conditional write failure as duplicate event", async () => {
  process.env.IDEMPOTENCY_TABLE_NAME = "idempotency-table";
  process.env.ORDERS_TABLE_NAME = "orders-table";

  const transactionError = new Error("duplicate");
  transactionError.name = "TransactionCanceledException";
  transactionError.CancellationReasons = [{ Code: "ConditionalCheckFailed" }];

  const { handler, metricCalls, loggerCalls, sendCalls } =
    createProcessorHandler({ transactionError });

  const result = await handler({
    Records: [
      {
        messageId: "msg-1",
        body: JSON.stringify({
          eventId: "evt-dup",
          eventName: "Order Created",
          eventType: "OrderCreated",
          payload: {
            order_id: "order-1",
            customer_id: 1001,
            amount: 149.9,
            currency: "USD",
          },
          _metadata: {
            correlationId: "corr-dup",
          },
        }),
      },
    ],
  });

  assert.deepEqual(result, { batchItemFailures: [] });
  assert.equal(sendCalls.length, 1);
  assert.equal(metricCalls[0].metricName, "EventDuplicated");
  assert.equal(
    loggerCalls[0].fields.message,
    "Idempotency: Duplicated Message ignored",
  );
});

test("processor retries when referenced sensitive Supabase row is missing", async () => {
  process.env.IDEMPOTENCY_TABLE_NAME = "idempotency-table";
  process.env.ORDERS_TABLE_NAME = "orders-table";

  const { handler, metricCalls, loggerCalls, supabaseChecks, sendCalls } =
    createProcessorHandler({
      supabaseError: new Error("Missing orders row for customer_id 1001"),
    });

  const result = await handler({
    Records: [
      {
        messageId: "msg-2",
        body: JSON.stringify({
          eventId: "evt-sensitive",
          eventName: "Order Created",
          eventType: "OrderCreated",
          payload: {
            order_id: "order-2",
            customer_id: 1001,
            amount: 149.9,
            currency: "USD",
            sensitive: {
              ssn_masked: "***-**-6789",
              ssn_ref: 1001,
            },
          },
          _metadata: {
            correlationId: "corr-sensitive",
          },
        }),
      },
    ],
  });

  assert.deepEqual(result, {
    batchItemFailures: [{ itemIdentifier: "msg-2" }],
  });
  assert.deepEqual(supabaseChecks, [1001]);
  assert.equal(sendCalls.length, 0);
  assert.equal(metricCalls[0].metricName, "EventRetried");
  assert.equal(
    loggerCalls[0].fields.error,
    "Missing orders row for customer_id 1001",
  );
});
