variable "project_name" {
  description = "Short name used to prefix/tag all resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from the networking module)"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs the ALB will live in (from the networking module)"
  type        = list(string)
}
