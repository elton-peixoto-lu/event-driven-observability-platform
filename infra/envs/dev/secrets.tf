resource "aws_secretsmanager_secret" "supabase" {
  name        = local.supabase_secret_name
  description = "Supabase credentials for orders lab"
  kms_key_id  = aws_kms_key.infra.arn

  tags = local.common_tags
}
