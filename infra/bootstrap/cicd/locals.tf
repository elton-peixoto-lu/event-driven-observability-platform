locals {
  repo_slug              = "${var.github_owner}/${var.github_repo}"
  allowed_repo_slugs     = distinct(concat([local.repo_slug], var.github_allowed_repositories))
  plan_allowed_subjects  = flatten([for repo in local.allowed_repo_slugs : ["repo:${repo}:pull_request", "repo:${repo}:ref:refs/heads/${var.default_branch}"]])
  apply_allowed_subjects = [for repo in local.allowed_repo_slugs : "repo:${repo}:ref:refs/heads/${var.default_branch}"]
  state_bucket_name      = "edop-tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
  lock_table_name        = "${var.project_name}-terraform-locks"
  state_key_prefix       = "terraform"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Stack       = "bootstrap-cicd"
  }
}
