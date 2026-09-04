##############################################################################
# LOAD BALANCER MODULE
#
# Creates: the ALB, its target group, and listener. Deliberately takes
# NO input from the ECS module — this avoids a circular dependency
# that project 2 solved with `aws_autoscaling_attachment`, but ECS
# has no equivalent separate "attachment" resource: the load balancer
# connection is a required inline block on `aws_ecs_service` itself.
# Since that inline block needs this module's target group ARN, the
# dependency can only flow one way: ECS depends on this module, and
# this module depends on nothing from ECS. The security group rule
# allowing ALB -> ECS traffic is therefore created in the ECS module
# instead (which CAN safely take this module's ALB security group ID
# as a one-directional input).
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_security_group" "alb" {
  #checkov:skip=CKV_AWS_260:This is a public-facing website's load balancer - accepting HTTP from anywhere on port 80 is the entire point of it, not a misconfiguration. HTTPS is a separate, documented decision below (see the listener resource).
  name        = "${var.project_name}-alb-sg"
  description = "ALB - allows inbound HTTP from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Scoped to the app port only - the ALB never needs to reach
  # anything else. Previously an unrestricted "-1/all ports" rule.
  # Scoped by port rather than security group reference, since this
  # module deliberately takes no input from the ECS module (see the
  # module-level comment above).
  egress {
    description = "App tier only"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
  }
}

resource "aws_lb" "app" {
  #checkov:skip=CKV_AWS_91:Access logging needs a new S3 bucket destination - genuinely new infrastructure and storage cost, out of scope for a zero-new-infrastructure security pass.
  #checkov:skip=CKV_AWS_150:Deletion protection would block this project's established terraform destroy-after-verification workflow, used specifically to keep AWS costs at zero between work sessions.
  #checkov:skip=CKV2_AWS_20:HTTP-to-HTTPS redirect requires HTTPS itself (see the listener resource below) - not possible without a registered domain.
  #checkov:skip=CKV2_AWS_28:WAF has a real recurring per-ACL and per-rule cost (~$5-10+/month) - deferred, out of scope for this project's cost-conscious design.
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # Free, no functional downside - rejects malformed/ambiguous HTTP
  # headers instead of forwarding them.
  drop_invalid_header_fields = true

  tags = {
    Name    = "${var.project_name}-alb"
    Project = var.project_name
  }
}

resource "aws_lb_target_group" "app" {
  #checkov:skip=CKV_AWS_378:HTTP target group protocol is a direct consequence of the HTTPS decision on the listener below - same root cause, same justification.
  name        = "${var.project_name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # required for Fargate — tasks are registered by IP, not instance ID

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${var.project_name}-tg"
    Project = var.project_name
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:HTTPS requires a registered domain name + ACM certificate, which this project deliberately doesn't have (unlike project 1, which does own sunsetheard.dev) - a genuine scope decision, not an oversight.
  #checkov:skip=CKV_AWS_103:Same root cause as CKV_AWS_2 above - TLS policy is moot without an HTTPS listener to apply it to.
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
