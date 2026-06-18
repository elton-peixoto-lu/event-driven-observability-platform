# CI/CD Foundation Bootstrap

This Terraform stack creates the AWS foundation required to operate this repository with professional GitHub Actions based CI/CD:

- GitHub OIDC provider for short-lived AWS federation
- remote Terraform state bucket
- DynamoDB lock table for Terraform state locking
- KMS key for Terraform state encryption
- GitHub Actions plan role
- GitHub Actions apply role

If you also run CI from a fork, add that repository slug to `github_allowed_repositories` so the AWS OIDC trust policy accepts both the upstream and the fork. If your apply workflow targets a GitHub environment, keep `github_apply_environment_name` aligned with that environment so the apply role accepts the OIDC subject emitted by GitHub.

## Apply

```bash
cd infra/bootstrap/cicd
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform apply
```

## Next Step

After apply, copy `backend.hcl.example` to a local, unversioned `backend.hcl`, replace the placeholder values with the Terraform outputs, and reinitialize the application stack:

```bash
cp infra/bootstrap/cicd/backend.hcl.example infra/envs/dev/backend.hcl
cd infra/envs/dev
terraform init -reconfigure -backend-config=backend.hcl
```

The GitHub workflows should then assume one of these roles through OIDC:

- `github_actions_plan_role_arn`
- `github_actions_apply_role_arn`
