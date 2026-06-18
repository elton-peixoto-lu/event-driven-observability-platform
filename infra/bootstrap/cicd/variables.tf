variable "region" {
  description = "AWS region for the CI/CD foundation resources"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name used in CI/CD foundation resource names"
  type        = string
  default     = "event-driven-observability-platform"
}

variable "environment" {
  description = "Foundation environment marker"
  type        = string
  default     = "shared"
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repository"
  type        = string
  default     = "willianferreira"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "event-driven-observability-platform"
}

variable "github_allowed_repositories" {
  description = "Additional GitHub repositories allowed to assume the CI/CD roles via OIDC"
  type        = list(string)
  default     = []
}

variable "default_branch" {
  description = "Default branch allowed to run apply"
  type        = string
  default     = "main"
}

variable "state_bucket_force_destroy" {
  description = "Whether the Terraform state bucket can be force destroyed"
  type        = bool
  default     = false
}
