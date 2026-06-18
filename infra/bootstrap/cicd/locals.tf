locals {
  repo_slug         = "${var.github_owner}/${var.github_repo}"
  state_bucket_name = "edop-tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
  lock_table_name   = "${var.project_name}-terraform-locks"
  state_key_prefix  = "terraform"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "bootstrap-cicd"
  }
}
