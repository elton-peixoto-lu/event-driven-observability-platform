locals {
  supabase_secret_name   = trimspace(var.supabase_secret_name) != "" ? var.supabase_secret_name : "${var.environment}/orders/supabase"
  cloudtrail_bucket_name = "edop-${var.environment}-${data.aws_caller_identity.current.account_id}-audit-trail"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
