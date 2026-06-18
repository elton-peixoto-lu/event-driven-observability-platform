data "aws_iam_policy_document" "terraform_state_access" {
  statement {
    sid    = "TerraformStateBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid    = "TerraformStateObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*"]
  }

  statement {
    sid    = "TerraformLockTableAccess"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem",
    ]
    resources = [aws_dynamodb_table.terraform_locks.arn]
  }

  statement {
    sid    = "TerraformStateKmsAccess"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.terraform_state.arn]
  }
}

resource "aws_iam_policy" "terraform_state_access" {
  name   = "${var.project_name}-terraform-state-access"
  policy = data.aws_iam_policy_document.terraform_state_access.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions_plan_state_access" {
  role       = aws_iam_role.github_actions_plan.name
  policy_arn = aws_iam_policy.terraform_state_access.arn
}

resource "aws_iam_role_policy_attachment" "github_actions_apply_state_access" {
  role       = aws_iam_role.github_actions_apply.name
  policy_arn = aws_iam_policy.terraform_state_access.arn
}

resource "aws_iam_role_policy_attachment" "github_actions_plan_readonly" {
  role       = aws_iam_role.github_actions_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "github_actions_apply_services" {
  statement {
    sid    = "ProjectInfrastructureServices"
    effect = "Allow"
    actions = [
      "apigateway:*",
      "cloudtrail:*",
      "cloudwatch:*",
      "cognito-idp:*",
      "dynamodb:*",
      "iam:*",
      "kms:*",
      "lambda:*",
      "logs:*",
      "s3:*",
      "secretsmanager:*",
      "sns:*",
      "sqs:*",
      "tag:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PassRoles"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project_name}-*",
      aws_iam_role.github_actions_plan.arn,
      aws_iam_role.github_actions_apply.arn,
    ]
  }

  statement {
    sid    = "ReadAccountContext"
    effect = "Allow"
    actions = [
      "sts:GetCallerIdentity",
      "iam:GetAccountSummary",
      "iam:ListAccountAliases",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "github_actions_apply_services" {
  name   = "${var.project_name}-github-actions-apply-services"
  policy = data.aws_iam_policy_document.github_actions_apply_services.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_actions_apply_services" {
  role       = aws_iam_role.github_actions_apply.name
  policy_arn = aws_iam_policy.github_actions_apply_services.arn
}
