# Troubleshooting Log

Real issues hit while building this project, with root cause and fix.
Format: symptom → cause → fix.

---

## Phase 0 — Project Scaffold & State

*(No issues — reused existing backend, same pattern as project 2.)*

## Phase 2 — Database Tier

### Reminder from project 2: check the Postgres engine version before applying
RDS periodically deprecates old minor versions, and the version
pinned in `modules/database/main.tf` may not always be current. This
was a real issue hit in project 2 — checking with `aws rds describe-
db-engine-versions` before planning avoided it happening again here.

### Reminder from project 2: security group descriptions must be plain ASCII
AWS rejects `aws_security_group` `description` fields containing
non-ASCII characters (like an em dash). This module's descriptions
were written with plain hyphens from the start, applying that lesson
proactively rather than hitting the same error again.

## Phase 4 — ECS, Fargate, Load Balancer

### ECS tasks stuck "PENDING" or cycling, never reaching "RUNNING"
**Cause:** almost always one of: the execution role can't pull the
image (check the IAM role has `AmazonECSTaskExecutionRolePolicy`
attached), the execution role can't read the SSM secrets (check the
`ssm:GetParameters` — plural — permission and the KMS decrypt
condition), or the security group blocks required outbound traffic
(tasks need outbound HTTPS to reach ECR and SSM endpoints).
**Fix:** check `aws ecs describe-services` for `events` — ECS reports
specific failure reasons there (e.g. "unable to pull secrets" or
"CannotPullContainerError"). Also check
`aws logs tail /ecs/ecs-guestbook` for anything the container itself
logged before dying.

### Targets show "unhealthy" right after apply
**Cause:** normal — same as project 2's equivalent note. The health
check needs a couple of passing checks before marking a target
healthy, and Fargate tasks take a little time to launch and start
listening on their port.
**Fix:** wait 2-4 minutes and re-check. If still unhealthy after 5+
minutes, confirm the target group's health check path (`/health`) and
port (8080) match the app, and that the `ecs_from_alb` security group
rule actually applied.

---

*(Further refinements will be added as they come up.)*
