"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const { createLogger } = require("../../services/shared/logger");

test("logger redacts known secret fields automatically", () => {
  const output = [];
  const originalLog = console.log;
  console.log = (line) => output.push(JSON.parse(line));

  try {
    const logger = createLogger({
      service: "test-service",
      authorization: "Bearer should-not-appear",
    });

    logger.info({
      nested: {
        apikey: "super-secret",
        service_role_token: "top-secret",
      },
      normalField: "visible",
    });
  } finally {
    console.log = originalLog;
  }

  assert.equal(output.length, 1);
  assert.equal(output[0].authorization, "[REDACTED]");
  assert.equal(output[0].nested.apikey, "[REDACTED]");
  assert.equal(output[0].nested.service_role_token, "[REDACTED]");
  assert.equal(output[0].normalField, "visible");
});
