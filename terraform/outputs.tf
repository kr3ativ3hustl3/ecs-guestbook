output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (used by ALB and Fargate tasks, later phases)"
  value       = module.networking.public_subnet_ids
}

output "database_subnet_ids" {
  description = "Database subnet IDs (for RDS, later phases)"
  value       = module.networking.database_subnet_ids
}

output "db_endpoint" {
  description = "RDS connection endpoint"
  value       = module.database.db_endpoint
}

output "db_security_group_id" {
  description = "RDS security group ID — needed when wiring up ECS in Phase 4"
  value       = module.database.security_group_id
}

output "ecr_repository_url" {
  description = "ECR repository URL — used by the build/push workflow and the ECS task definition"
  value       = module.ecr.repository_url
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC — paste into the GitHub secret AWS_GITHUB_ACTIONS_ROLE_ARN"
  value       = module.github_cicd.role_arn
}
