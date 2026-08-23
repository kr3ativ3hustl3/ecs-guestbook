variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from the networking module)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the Fargate tasks will live in (from the networking module)"
  type        = list(string)
}

variable "ecr_repository_url" {
  description = "ECR repository URL (from the ecr module) — the task definition pulls the :latest tag from here"
  type        = string
}

variable "db_address" {
  description = "RDS host address (from the database module)"
  type        = string
}

variable "db_port" {
  description = "RDS port (from the database module)"
  type        = number
}

variable "db_name" {
  description = "Database name (from the database module)"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
}

variable "db_password" {
  description = "Database password — passed through to SSM Parameter Store as a SecureString"
  type        = string
  sensitive   = true
}

variable "db_security_group_id" {
  description = "RDS security group ID (from the database module) — gets the new ingress rule allowing ECS task traffic"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID (from the load-balancer module) — the ECS tasks' security group allows traffic from this one"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN (from the load-balancer module) — the ECS service registers its tasks here"
  type        = string
}
