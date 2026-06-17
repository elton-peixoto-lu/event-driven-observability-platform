resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = local.cloudtrail_bucket_name
  force_destroy = false

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "cloudtrail_s3" {
  statement {
    sid    = "AWSCloudTrailAclCheck"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail_logs.arn]
  }

  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = data.aws_iam_policy_document.cloudtrail_s3.json
}

resource "aws_cloudwatch_log_group" "cloudtrail_audit" {
  name              = "/aws/cloudtrail/${var.project_name}-${var.environment}-audit"
  retention_in_days = var.cloudtrail_log_retention_days

  tags = local.common_tags
}

data "aws_iam_policy_document" "cloudtrail_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  name               = "${var.project_name}-${var.environment}-cloudtrail-to-cw"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_assume_role.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "cloudtrail_to_cloudwatch" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.cloudtrail_audit.arn}:log-stream:*"
    ]
  }
}

resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch" {
  name   = "${var.project_name}-${var.environment}-cloudtrail-to-cw"
  role   = aws_iam_role.cloudtrail_to_cloudwatch.id
  policy = data.aws_iam_policy_document.cloudtrail_to_cloudwatch.json
}

resource "aws_cloudtrail" "audit" {
  name                          = "${var.project_name}-${var.environment}-audit"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail_audit.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_to_cloudwatch.arn
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_metric_filter" "secret_read_events" {
  name           = "${var.project_name}-secret-read-events"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_audit.name
  pattern        = "{ (($.eventSource = secretsmanager.amazonaws.com) && ($.eventName = GetSecretValue)) || (($.eventSource = ssm.amazonaws.com) && (($.eventName = GetParameter) || ($.eventName = GetParameters) || ($.eventName = GetParametersByPath))) }"

  metric_transformation {
    name      = "${var.project_name}-SecretReadEvents"
    namespace = "${var.project_name}/audit"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "secret_change_events" {
  name           = "${var.project_name}-secret-change-events"
  log_group_name = aws_cloudwatch_log_group.cloudtrail_audit.name
  pattern        = "{ (($.eventSource = secretsmanager.amazonaws.com) && (($.eventName = PutSecretValue) || ($.eventName = UpdateSecret) || ($.eventName = UpdateSecretVersionStage) || ($.eventName = RotateSecret))) || (($.eventSource = ssm.amazonaws.com) && (($.eventName = PutParameter) || ($.eventName = DeleteParameter) || ($.eventName = DeleteParameters))) }"

  metric_transformation {
    name      = "${var.project_name}-SecretChangeEvents"
    namespace = "${var.project_name}/audit"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "secret_change_events" {
  alarm_name          = "${var.project_name}-secret-change-events"
  alarm_description   = "Triggers when Secrets Manager or Parameter Store values are changed or rotated"
  namespace           = "${var.project_name}/audit"
  metric_name         = "${var.project_name}-SecretChangeEvents"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  treat_missing_data  = "notBreaching"
  comparison_operator = "GreaterThanOrEqualToThreshold"

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = local.common_tags
}
