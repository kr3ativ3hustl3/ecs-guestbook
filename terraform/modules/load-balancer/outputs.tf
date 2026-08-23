output "alb_dns_name" {
  description = "The ALB's public DNS name — the URL to actually visit the site"
  value       = aws_lb.app.dns_name
}

output "alb_security_group_id" {
  description = "ALB security group ID — the ECS module uses this to allow inbound traffic from the ALB specifically"
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "Target group ARN — the ECS service registers itself here"
  value       = aws_lb_target_group.app.arn
}

output "listener_arn" {
  description = "Listener ARN — used to force an explicit dependency ordering from the ECS module"
  value       = aws_lb_listener.http.arn
}
