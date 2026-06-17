variable "region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project to be used in resource naming"
  type        = string
  default     = "event-driven-observability-platform"
}

variable "alerts_email" {
  description = "Email that will receive alerts from SNS"
  type        = string

  validation {
    condition     = length(trimspace(var.alerts_email)) > 0
    error_message = "alerts_email must be a non-empty email address."
  }
}

variable "supabase_secret_name" {
  description = "Secrets Manager secret container name for Supabase credentials"
  type        = string
  default     = ""
}

variable "cloudtrail_log_retention_days" {
  description = "Retention in days for CloudTrail audit logs in CloudWatch Logs"
  type        = number
  default     = 90
}
