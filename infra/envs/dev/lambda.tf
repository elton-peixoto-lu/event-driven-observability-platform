resource "aws_lambda_function" "ingestion" {
  function_name = "${var.project_name}-ingestion"
  role          = aws_iam_role.lambda_ingestion.arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"

  filename         = "../../../artifacts/ingestion/function.zip"
  source_code_hash = filebase64sha256("../../../artifacts/ingestion/function.zip")

  timeout     = 10
  memory_size = 256

  environment {
    variables = {
      SQS_QUEUE_URL                       = aws_sqs_queue.events.url
      METRICS_NAMESPACE                   = "ObservabilityPlatform"
      SUPABASE_SECRET_ARN                 = aws_secretsmanager_secret.supabase.arn
      ENVIRONMENT                         = var.environment
      SENSITIVE_FIELDS_KMS_KEY_ID         = aws_kms_key.infra.arn
      SENSITIVE_FIELDS_ENCRYPTION_VERSION = "kms-v1"
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_function" "processor" {
  function_name = "${var.project_name}-processor"
  role          = aws_iam_role.lambda_processing.arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"

  filename         = "../../../artifacts/processor/function.zip"
  source_code_hash = filebase64sha256("../../../artifacts/processor/function.zip")

  timeout     = 10
  memory_size = 256

  environment {
    variables = {
      IDEMPOTENCY_TABLE_NAME              = aws_dynamodb_table.idempotency.name
      ORDERS_TABLE_NAME                   = aws_dynamodb_table.orders.name
      METRICS_NAMESPACE                   = "ObservabilityPlatform"
      SUPABASE_SECRET_ARN                 = aws_secretsmanager_secret.supabase.arn
      ENVIRONMENT                         = var.environment
      SENSITIVE_FIELDS_KMS_KEY_ID         = aws_kms_key.infra.arn
      SENSITIVE_FIELDS_ENCRYPTION_VERSION = "kms-v1"
    }
  }

  tags = local.common_tags
}
