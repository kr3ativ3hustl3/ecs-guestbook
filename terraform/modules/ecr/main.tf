##############################################################################
# ECR MODULE
#
# Creates: a private container repository for the guestbook app image,
# with vulnerability scanning on every push, and a lifecycle policy
# that automatically cleans up old untagged images so the repo
# doesn't quietly accumulate storage over time.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_ecr_repository" "app" {
  #checkov:skip=CKV_AWS_51:MUTABLE is the deliberate, already-documented design choice explained in the comment directly below - a floating "latest" tag with explicit ECS redeploy, not an oversight.
  name = "${var.project_name}-app"

  # MUTABLE, not IMMUTABLE — a deliberate simplicity tradeoff. This
  # project uses a floating "latest" tag that gets overwritten on
  # every build, with ECS explicitly told to redeploy afterward
  # (Phase 5). A more production-grade pipeline would tag every build
  # with a unique identifier (e.g. the git commit SHA) and update the
  # ECS task definition to reference that exact tag — giving a precise
  # audit trail of what's deployed and making rollback trivial. That
  # approach needs IMMUTABLE tags (an existing tag can never be
  # silently overwritten) plus task-definition-per-deploy logic, which
  # is more machinery than this portfolio project's scope calls for,
  # but worth knowing as the "real" answer if asked in an interview.
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Encrypted using AWS's default ECR-managed KMS key - free, no
  # per-key charge like a Customer-Managed Key would have. A genuine
  # upgrade over the previous default (AES256) at no cost.
  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name    = "${var.project_name}-app"
    Project = var.project_name
  }
}

# Automatically expires untagged images (leftover from overwritten
# "latest" tags) after 7 days — keeps the repo from silently growing
# forever. Tagged images are never touched by this rule.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images older than 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = {
        type = "expire"
      }
    }]
  })
}
