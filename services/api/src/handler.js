exports.handler = async (event) => {
  const failures = [];

  for (const record of event.Records) {
    try {
      const body = JSON.parse(record.body);

      console.log(
        JSON.stringify({
          level: "INFO",
          messageId: record.messageId,
          payload: body,
        }),
      );

      // Transient failure
      if (body.failTransient) {
        throw new Error("Transient processing error");
      }

      // Permanent error
      if (!body.type) {
        console.log(
          JSON.stringify({
            level: "WARN",
            messageId: record.messageId,
            reason: "Missing required field: type",
          }),
        );
        continue;
      }
    } catch (err) {
      console.log(
        JSON.stringify({
          level: "ERROR",
          messageId: record.messageId,
          error: err.message,
        }),
      );

      failures.push({
        itemIdentifier: record.messageId,
      });
    }
  }

  return {
    batchItemFailures: failures,
  };
};
