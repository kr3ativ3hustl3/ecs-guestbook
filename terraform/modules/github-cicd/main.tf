##############################################################################
# GITHUB CI/CD MODULE
#
# Lets GitHub Actions build and push container images to this
# project's ECR repository via OIDC — no long-lived AWS credentials
# in GitHub.
#
# Reuses the EXISTING GitHub OIDC provider (registered once per AWS
# account, not per project — see project 2's docs/troubleshooting.md
# for the "already exists" collision this avoids) via a data source,
# and uses StringLike (not StringEquals) for the repo condition, since
# GitHub's OIDC subject claim includes numeric owner/repo IDs that
# StringEquals would never match (a real bug hit and fixed in
# project 1, applied proactively here from the start).
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${split("/", var.github_repo)[0]}*/${split("/", var.github_repo)[1]}*:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  tags = {
    Project = var.project_name
  }
}

# Split into two statements for the same reason discovered in
# project 2: not every AWS action supports resource-level IAM
# scoping. ecr:GetAuthorizationToken specifically requires
# Resource: "*" — it cannot be scoped to one repository, regardless
# of intent. The actual push actions DO support scoping to one
# specific repository ARN.
resource "aws_iam_role_policy" "ecr_push" {
  name = "${var.project_name}-ecr-push"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GetAuthTokenRequiresWildcard"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "PushToThisRepoOnly"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
        ]
        Resource = var.ecr_repository_arn
      },
    ]
  })
}
