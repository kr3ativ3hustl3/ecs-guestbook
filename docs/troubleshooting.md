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
