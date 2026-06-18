resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    "ffffffffffffffffffffffffffffffffffffffff",
  ]

  tags = local.common_tags
}

data "aws_iam_policy_document" "github_actions_plan_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.plan_allowed_subjects
    }
  }
}

data "aws_iam_policy_document" "github_actions_apply_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.apply_allowed_subjects
    }
  }
}

resource "aws_iam_role" "github_actions_plan" {
  name               = "${var.project_name}-github-actions-plan"
  assume_role_policy = data.aws_iam_policy_document.github_actions_plan_assume.json

  tags = local.common_tags
}

resource "aws_iam_role" "github_actions_apply" {
  name               = "${var.project_name}-github-actions-apply"
  assume_role_policy = data.aws_iam_policy_document.github_actions_apply_assume.json

  tags = local.common_tags
}
