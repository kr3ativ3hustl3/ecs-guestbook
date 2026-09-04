##############################################################################
# ROOT MODULE — ECS Guestbook Project (project 3)
#
# Reuses the SAME S3 bucket + DynamoDB lock table as projects 1 and 2
# — no new state backend setup needed. The `key` below keeps this
# project's state completely separate from the other two.
##############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "sunificent-cloud-resume-tf-state-2026"
    key            = "ecs-guestbook/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloud-resume-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  providers = { aws = aws }

  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  db_subnet_cidrs     = var.db_subnet_cidrs
}

module "database" {
  source = "./modules/database"

  providers = { aws = aws }

  project_name        = var.project_name
  vpc_id              = module.networking.vpc_id
  database_subnet_ids = module.networking.database_subnet_ids
  db_username         = var.db_username
  db_password         = var.db_password
}

module "ecr" {
  source = "./modules/ecr"

  providers = { aws = aws }

  project_name = var.project_name
}

module "github_cicd" {
  source = "./modules/github-cicd"

  providers = { aws = aws }

  project_name       = var.project_name
  github_repo        = var.github_repo
  ecr_repository_arn = module.ecr.repository_arn
  ecs_service_arn    = module.ecs.service_arn
}

module "load_balancer" {
  source = "./modules/load-balancer"

  providers = { aws = aws }

  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
}

module "ecs" {
  source = "./modules/ecs"

  providers = { aws = aws }

  # Ensures every resource in the load-balancer module (including the
  # listener) exists before Terraform creates anything in this module
  # — a target group with no listener yet can prevent the ECS service
  # from stabilizing correctly.
  depends_on = [module.load_balancer]

  project_name          = var.project_name
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  ecr_repository_url    = module.ecr.repository_url
  db_address            = module.database.db_address
  db_port               = module.database.db_port
  db_name               = module.database.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  db_security_group_id  = module.database.security_group_id
  alb_security_group_id = module.load_balancer.alb_security_group_id
  target_group_arn      = module.load_balancer.target_group_arn
}
