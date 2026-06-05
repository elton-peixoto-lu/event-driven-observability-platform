resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alerts_email
}