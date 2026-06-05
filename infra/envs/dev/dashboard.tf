resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-system-health"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: System Overview
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 0
        properties = {
          metrics = [
            ["ObservabilityPlatform", "EventProcessed", "Service", "processor", { stat = "Sum", label = "Total Events Processed" }]
          ]
          view   = "singleValue"
          region = var.region
          title  = "Total Events Processed"
          period = 900
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 0
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.events.name, { stat = "Maximum", label = "Messages in Queue" }]
          ]
          view   = "singleValue"
          region = var.region
          title  = "Messages in Queue"
          period = 300
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 0
        properties = {
          metrics = [
            [{ expression = "m1+m2", label = "Total Failures", id = "e1", color = "#d62728" }],
            ["ObservabilityPlatform", "EventRetried", "Service", "processor", { id = "m1", stat = "Sum", visible = false }],
            ["ObservabilityPlatform", "EventFailed", "Service", "ingestion", { id = "m2", stat = "Sum", visible = false }]
          ]
          view   = "singleValue"
          region = var.region
          title  = "Total Failures (3h)"
          period = 900
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 6
        properties = {
          metrics = [
            ["${var.project_name}/api-gateway", "${var.project_name}-Api4xxCount", { stat = "Sum", label = "4xx Errors", color = "#ff7f0e" }],
            [".", "${var.project_name}-Api5xxCount", { stat = "Sum", label = "5xx Errors", color = "#d62728" }],
            ["ObservabilityPlatform", "EventRejected", "Service", "ingestion", { stat = "Sum", label = "Rejected (bad payload)", color = "#9467bd" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "API Requests by Status"
          period  = 60
          yAxis = {
            left = { min = 0 }
          }
          annotations = {
            horizontal = [{
              value = 5
              label = "4xx Alarm Threshold"
              fill  = "above"
              color = "#ff7f0e"
            }]
          }
        }
      },
      {
        type   = "log"
        width  = 6
        height = 6
        x      = 12
        y      = 6
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.api_gateway_logs.name}' | fields @timestamp, latency | stats avg(latency), pct(latency, 50), pct(latency, 99) by bin(5m)"
          region  = var.region
          title   = "API Latency (ms)"
          stacked = false
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 18
        y      = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.ingestion.function_name, { stat = "Average", label = "Avg Duration" }],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.ingestion.function_name, { stat = "p99", label = "p99 Duration" }],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.ingestion.function_name, { stat = "Sum", label = "Errors", yAxis = "right", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Ingestion Lambda Performance"
          period  = 300
          yAxis = {
            left  = { label = "Duration (ms)", min = 0 }
            right = { label = "Errors", min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 12
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.events.name, { stat = "Maximum", label = "Max Depth" }],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.events.name, { stat = "Average", label = "Avg Depth" }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.region
          title   = "SQS Queue Depth"
          period  = 300
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 12
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateAgeOfOldestMessage", "QueueName", aws_sqs_queue.events.name, { stat = "Maximum", label = "Queue Lag" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Queue Age (seconds)"
          period  = 60
          yAxis = {
            left = { min = 0 }
          }
          annotations = {
            horizontal = [{
              value = 120
              label = "2min Threshold"
              fill  = "above"
              color = "#d62728"
            }]
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 12
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.events_dlq.name, { stat = "Maximum", label = "DLQ Messages" }]
          ]
          view   = "singleValue"
          region = var.region
          title  = "Dead Letter Queue"
          period = 300
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 0
        y      = 18
        properties = {
          metrics = [
            ["ObservabilityPlatform", "EventIngested", "Service", "ingestion", { stat = "Sum", label = "Ingested", color = "#2ca02c" }],
            ["ObservabilityPlatform", "EventProcessed", "Service", "processor", { stat = "Sum", label = "Processed", color = "#1f77b4" }],
            ["ObservabilityPlatform", "EventRejected", "Service", "processor", { stat = "Sum", label = "Rejected (schema)", color = "#9467bd" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Processing Throughput (events/min)"
          period  = 60
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 6
        y      = 18
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.processor.function_name, { stat = "Average", label = "Avg Duration" }],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.processor.function_name, { stat = "p99", label = "p99 Duration" }],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.processor.function_name, { stat = "Sum", label = "Errors", yAxis = "right", color = "#d62728" }],
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", aws_lambda_function.processor.function_name, { stat = "Maximum", label = "Concurrency", yAxis = "right", color = "#9467bd" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Processor Lambda Health"
          period  = 300
          yAxis = {
            left  = { label = "Duration (ms)", min = 0 }
            right = { label = "Count", min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 12
        y      = 18
        properties = {
          metrics = [
            ["AWS/DynamoDB", "UserErrors", "TableName", aws_dynamodb_table.idempotency.name, { stat = "Sum", label = "User Errors" }],
            ["AWS/DynamoDB", "SystemErrors", "TableName", aws_dynamodb_table.idempotency.name, { stat = "Sum", label = "System Errors", color = "#d62728" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "DynamoDB Idempotency Table Errors"
          period  = 300
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "alarm"
        width  = 6
        height = 6
        x      = 18
        y      = 18
        properties = {
          title = "Alarm Status"
          alarms = [
            aws_cloudwatch_metric_alarm.api_4xx_spike.arn,
            aws_cloudwatch_metric_alarm.lambda_errors.arn,
            aws_cloudwatch_metric_alarm.dlq_depth.arn,
            aws_cloudwatch_metric_alarm.queue_lag.arn
          ]
        }
      },
      # Row 5: Event Loss Detection
      {
        type   = "metric"
        width  = 12
        height = 6
        x      = 0
        y      = 24
        properties = {
          metrics = [
            ["ObservabilityPlatform", "EventIngested", "Service", "ingestion", { id = "m1", stat = "Sum", label = "Ingested", color = "#2ca02c" }],
            ["ObservabilityPlatform", "EventProcessed", "Service", "processor", { id = "m2", stat = "Sum", label = "Processed", color = "#1f77b4" }],
            ["ObservabilityPlatform", "EventRejected", "Service", "processor", { id = "m3", stat = "Sum", label = "Rejected", color = "#d62728" }],
            ["ObservabilityPlatform", "EventDuplicated", "Service", "processor", { id = "m4", stat = "Sum", label = "Duplicated", color = "#ff7f0e" }],
            ["ObservabilityPlatform", "EventRetried", "Service", "processor", { id = "m5", stat = "Sum", label = "Retried", color = "#e377c2" }],
            [{ expression = "FILL(m1,0)-FILL(m2,0)-FILL(m3,0)-FILL(m4,0)-FILL(m5,0)", label = "Potential Loss", id = "e1", color = "#8c564b" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Event Flow & Loss Detection"
          period  = 60
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 12
        y      = 24
        properties = {
          metrics = [
            [{ expression = "FILL(m1,0)-FILL(m2,0)-FILL(m3,0)-FILL(m4,0)-FILL(m5,0)", label = "Events Lost (24h)", id = "e1" }],
            ["ObservabilityPlatform", "EventIngested", "Service", "ingestion", { id = "m1", stat = "Sum", visible = false }],
            ["ObservabilityPlatform", "EventProcessed", "Service", "processor", { id = "m2", stat = "Sum", visible = false }],
            ["ObservabilityPlatform", "EventRejected", "Service", "processor", { id = "m3", stat = "Sum", visible = false }],
            ["ObservabilityPlatform", "EventDuplicated", "Service", "processor", { id = "m4", stat = "Sum", visible = false }],
            ["ObservabilityPlatform", "EventRetried", "Service", "processor", { id = "m5", stat = "Sum", visible = false }]
          ]
          view   = "singleValue"
          region = var.region
          title  = "Potential Event Loss (24h)"
          period = 86400
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 18
        y      = 24
        properties = {
          metrics = [
            [{ expression = "IF(m1>0, (m2/m1)*100, 0)", label = "Duplication Rate %", id = "e1" }],
            ["ObservabilityPlatform", "EventIngested", "Service", "ingestion", { id = "m1", stat = "Sum", visible = false }],
            ["ObservabilityPlatform", "EventDuplicated", "Service", "processor", { id = "m2", stat = "Sum", visible = false }]
          ]
          view   = "singleValue"
          region = var.region
          title  = "Duplication Rate %"
          period = 900
        }
      },
      # Row 6: Throttling & Limits
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 0
        y      = 30
        properties = {
          metrics = [
            ["AWS/Lambda", "Throttles", "FunctionName", aws_lambda_function.ingestion.function_name, { stat = "Sum", label = "Ingestion" }],
            ["AWS/Lambda", "Throttles", "FunctionName", aws_lambda_function.processor.function_name, { stat = "Sum", label = "Processor" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Lambda Throttle Events"
          period  = 300
          yAxis = {
            left = { min = 0 }
          }
          annotations = {
            horizontal = [{
              value = 1
              label = "Any throttle is critical"
              fill  = "above"
              color = "#d62728"
            }]
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 8
        y      = 30
        properties = {
          metrics = [
            ["AWS/Lambda", "ConcurrentExecutions", "FunctionName", aws_lambda_function.processor.function_name, { stat = "Maximum", label = "Processor Concurrency" }],
            ["AWS/Lambda", "UnreservedConcurrentExecutions", { stat = "Maximum", label = "Account Unreserved" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Lambda Concurrency vs Limits"
          period  = 300
          yAxis = {
            left = { min = 0 }
          }
          annotations = {
            horizontal = [{
              value = 900
              label = "Approaching limit (1000)"
              fill  = "above"
              color = "#ff7f0e"
            }]
          }
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        x      = 16
        y      = 30
        properties = {
          metrics = [
            ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", aws_dynamodb_table.idempotency.name, { stat = "Sum", label = "Write Throttles" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "DynamoDB Write Throttles"
          period  = 300
          yAxis = {
            left = { min = 0 }
          }
          annotations = {
            horizontal = [{
              value = 1
              label = "Should be 0 (PAY_PER_REQUEST)"
              fill  = "above"
              color = "#d62728"
            }]
          }
        }
      },
      # Row 7: FinOps Cost Indicators
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 0
        y      = 36
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.ingestion.function_name, { stat = "Sum", label = "Ingestion" }],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.processor.function_name, { stat = "Sum", label = "Processor" }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.region
          title   = "Lambda Invocations (Cost: $0.20/1M)"
          period  = 300
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 6
        y      = 36
        properties = {
          metrics = [
            [{ expression = "(m1/1000)*(256/1024)*i1", label = "Ingestion GB-sec", id = "e1", color = "#1f77b4" }],
            [{ expression = "(m2/1000)*(256/1024)*i2", label = "Processor GB-sec", id = "e2", color = "#ff7f0e" }],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.ingestion.function_name, { id = "m1", stat = "Average", visible = false }],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.processor.function_name, { id = "m2", stat = "Average", visible = false }],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.ingestion.function_name, { id = "i1", stat = "Sum", visible = false }],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.processor.function_name, { id = "i2", stat = "Sum", visible = false }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.region
          title   = "Lambda GB-seconds (Cost: $0.0000166667/GB-sec)"
          period  = 300
          yAxis = {
            left = { min = 0 }
          }
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 12
        y      = 36
        properties = {
          metrics = [
            [{ expression = "m1+m2", label = "Total SQS Requests", id = "e1" }],
            ["AWS/SQS", "NumberOfMessagesSent", "QueueName", aws_sqs_queue.events.name, { id = "m1", stat = "Sum", visible = false }],
            ["AWS/SQS", "NumberOfMessagesReceived", "QueueName", aws_sqs_queue.events.name, { id = "m2", stat = "Sum", visible = false }]
          ]
          view   = "singleValue"
          region = var.region
          title  = "SQS API Calls (24h) - 1M free, then $0.40/1M"
          period = 86400
        }
      },
      {
        type   = "metric"
        width  = 6
        height = 6
        x      = 18
        y      = 36
        properties = {
          metrics = [
            [{ expression = "(i1+i2)*0.0000002 + (m1*i1+m2*i2)*0.000000004166675", label = "Est. Daily Cost (USD)", id = "e1", color = "#2ca02c" }],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.ingestion.function_name, { id = "i1", stat = "Sum", visible = false }],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.processor.function_name, { id = "i2", stat = "Sum", visible = false }],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.ingestion.function_name, { id = "m1", stat = "Average", visible = false }],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.processor.function_name, { id = "m2", stat = "Average", visible = false }]
          ]
          view   = "singleValue"
          region = var.region
          title  = "Estimated Daily Lambda Cost"
          period = 86400
        }
      }
    ]
  })
}