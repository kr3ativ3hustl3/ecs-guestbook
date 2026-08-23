output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets — used by both the ALB and Fargate tasks"
  value       = aws_subnet.public[*].id
}

output "database_subnet_ids" {
  description = "IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC — useful for security group rules"
  value       = aws_vpc.main.cidr_block
}
