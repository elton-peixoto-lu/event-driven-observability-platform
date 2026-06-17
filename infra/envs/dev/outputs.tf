output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "cloudtrail_name" {
  description = "CloudTrail name used for secret and parameter audit events"
  value       = aws_cloudtrail.audit.name
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket storing CloudTrail audit logs"
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}

output "cloudtrail_log_group" {
  description = "CloudWatch Logs group receiving CloudTrail audit events"
  value       = aws_cloudwatch_log_group.cloudtrail_audit.name
}
