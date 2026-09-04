##############################################################################
# ECS MODULE
#
# Creates: an ECS cluster, CloudWatch log group, SSM Parameter Store
# entries for DB credentials, the task execution IAM role, a security
# group for the Fargate tasks, the task definition, and the service
# itself. Also creates the two security group rules connecting this
# module to the load-balancer and database modules — see the
# load-balancer module's header comment for why the dependency only
# flows in this one direction.
##############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Project = var.project_name
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 14

  tags = {
    Project = var.project_name
  }
}

##############################################################################
# SSM Parameter Store — same pattern as project 2, but this time
# injected natively via the task definition's `secrets` field rather
# than fetched by a shell script at boot.
##############################################################################

resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/db/host"
  type  = "String"
  value = var.db_address
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/${var.project_name}/db/port"
  type  = "String"
  value = tostring(var.db_port)
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/db/name"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.project_name}/db/username"
  type  = "String"
  value = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.project_name}/db/password"
  type  = "SecureString"
  value = var.db_password
}

##############################################################################
# IAM — task EXECUTION role only (no separate task role needed, since
# this app makes no direct AWS API calls at runtime; it only receives
# DB credentials as plain environment variables).
#
# Important, non-obvious ECS detail: secrets referenced in a task
# definition's `secrets` field are fetched by the ECS AGENT using the
# EXECUTION role, not a task role — a common point of confusion, since
# it's easy to assume application-facing permissions belong on a
# "task role" by name alone.
##############################################################################

resource "aws_iam_role" "execution" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = {
    Project = var.project_name
  }
}

# AWS's own managed policy covering ECR image pulls and CloudWatch
# Logs — the standard baseline every ECS execution role needs.
resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Least-privilege: read access to exactly this project's SSM
# parameter path, nothing else. Note the action is the PLURAL
# ssm:GetParameters (batch) — that's what the ECS agent actually calls
# under the hood for task definition secrets, not the singular
# ssm:GetParameter used elsewhere in these projects for single reads.
resource "aws_iam_role_policy" "read_db_params" {
  name = "${var.project_name}-read-db-params"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadDbParameters"
        Effect   = "Allow"
        Action   = ["ssm:GetParameters"]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/db/*"
      },
      {
        Sid      = "DecryptSecureStringParameter"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      },
    ]
  })
}

##############################################################################
# Security group and the two rules connecting this module to the
# load-balancer and database modules.
##############################################################################

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "ECS Fargate tasks - only accepts traffic from the ALB"
  vpc_id      = var.vpc_id

  # Scoped to what a Fargate task actually needs outbound: HTTPS for
  # pulling images from ECR, sending logs to CloudWatch, and reading
  # secrets from SSM Parameter Store, plus Postgres to reach RDS.
  # Previously an unrestricted "-1/all ports" rule.
  egress {
    description = "HTTPS - ECR, CloudWatch, SSM"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Postgres to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-ecs-tasks-sg"
    Project = var.project_name
  }
}

resource "aws_security_group_rule" "ecs_from_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_tasks.id
  source_security_group_id = var.alb_security_group_id
  description              = "Allow the ALB to reach the ECS tasks"
}

resource "aws_security_group_rule" "rds_from_ecs" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.db_security_group_id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow the ECS tasks to reach RDS"
}

##############################################################################
# Task definition + service
##############################################################################

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([{
    name      = "guestbook"
    image     = "${var.ecr_repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 8080
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }

    secrets = [
      { name = "DB_HOST", valueFrom = aws_ssm_parameter.db_host.arn },
      { name = "DB_PORT", valueFrom = aws_ssm_parameter.db_port.arn },
      { name = "DB_NAME", valueFrom = aws_ssm_parameter.db_name.arn },
      { name = "DB_USER", valueFrom = aws_ssm_parameter.db_username.arn },
      { name = "DB_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn },
    ]
  }])

  tags = {
    Project = var.project_name
  }
}

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "guestbook"
    container_port   = 8080
  }

  # Note: this service needs the ALB's listener to exist before it can
  # stabilize (a target group with no listener yet can cause issues).
  # That ordering can't be expressed here with `depends_on`, since this
  # module has no visibility into another module's resources directly
  # — only its declared outputs. Instead, the root module's call to
  # THIS module includes `depends_on = [module.load_balancer]`, which
  # correctly waits for every resource in that module (including the
  # listener) before creating anything here.

  tags = {
    Project = var.project_name
  }
}
