output "github_oidc_provider_arn" {
  description = "IAM OIDC provider ARN for GitHub Actions"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_plan_role_arn" {
  description = "Role ARN for GitHub Actions terraform plan jobs"
  value       = aws_iam_role.github_actions_plan.arn
}

output "github_actions_apply_role_arn" {
  description = "Role ARN for GitHub Actions terraform apply jobs"
  value       = aws_iam_role.github_actions_apply.arn
}

output "terraform_state_bucket" {
  description = "S3 bucket that stores Terraform remote state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "terraform_lock_table" {
  description = "DynamoDB table used for Terraform state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "terraform_state_kms_key_arn" {
  description = "KMS key ARN used to encrypt Terraform remote state"
  value       = aws_kms_key.terraform_state.arn
}

output "backend_hcl_example" {
  description = "Ready-to-copy backend.hcl content for application stacks"
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.terraform_state.bucket}"
    key            = "terraform/envs/dev/terraform.tfstate"
    region         = "${var.region}"
    dynamodb_table = "${aws_dynamodb_table.terraform_locks.name}"
    encrypt        = true
    kms_key_id     = "${aws_kms_key.terraform_state.arn}"
  EOT
}
