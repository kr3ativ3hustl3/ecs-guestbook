output "repository_url" {
  description = "ECR repository URL — used by docker build/push and the ECS task definition"
  value       = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN — used to scope the GitHub Actions IAM policy"
  value       = aws_ecr_repository.app.arn
}

output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}
