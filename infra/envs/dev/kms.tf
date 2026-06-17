resource "aws_kms_key" "infra" {
  description             = "KMS key for ${var.project_name} secrets and sensitive field encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.common_tags
}

resource "aws_kms_alias" "infra" {
  name          = "alias/${var.project_name}-${var.environment}"
  target_key_id = aws_kms_key.infra.key_id
}
