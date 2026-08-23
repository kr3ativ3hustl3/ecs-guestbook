# Phase 2 — Database Tier

Creates: a DB subnet group, an RDS Postgres instance in the isolated
database subnets, and a security group with zero inbound rules (same
locked-down pattern as project 2).

---

## 1. Set a real database password

```bash
cd ~/projects/ecs-guestbook/terraform
```

Edit `terraform.tfvars` and replace the placeholder password with a
real, strong one (8+ characters):

```
db_password = "something-long-and-random"
```

## 2. Check the Postgres version is still valid

```bash
aws rds describe-db-engine-versions \
  --engine postgres \
  --query "DBEngineVersions[?EngineVersion.starts_with(@, '16.')].EngineVersion" \
  --output table \
  --profile cloud-resume
```

Confirm `16.4` (or whatever's pinned in `modules/database/main.tf`) is
in that list. If not, update the version in the module.

## 3. Plan and apply

```bash
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect **3 resources to add**: DB subnet group, security group, RDS
instance. Phase 1's networking should show no changes.

```bash
terraform apply
```

**This takes 5-10 minutes** — RDS provisioning is genuinely slow, same
as project 2. Normal, not stuck.

## 4. Verify

```bash
terraform output db_endpoint
```

Should return a real hostname. Nothing can connect to it yet — that's
correct, the security group still blocks everything until Phase 4.

---

## Verification checklist before moving to Phase 3

- [ ] `terraform apply` completed with no errors
- [ ] `terraform output db_endpoint` returns a real hostname
- [ ] RDS shows "Available" status in the AWS Console

Once confirmed, we'll move to **Phase 3: ECR + the GitHub Actions
workflow that builds and pushes the container image** — this is where
Docker enters the picture, entirely inside CI, never on your Mac.
