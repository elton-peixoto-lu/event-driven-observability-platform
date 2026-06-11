function emitMetric({ namespace, metricName, service, value = 1 }) {
  const metric = {
    _aws: {
      Timestamp: Date.now(),
      CloudWatchMetrics: [
        {
          Namespace: namespace,
          Dimensions: [["Service"]],
          Metrics: [{ Name: metricName, Unit: "Count" }],
        },
      ],
    },
    Service: service,
    [metricName]: value,
  };

  console.log(JSON.stringify(metric));
}

module.exports = { emitMetric };
