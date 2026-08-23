# Phase 0 — Project Scaffold & Terraform State

No new AWS account setup needed — reuses the state backend from
projects 1-2.

---

## Cost note

This project runs roughly **$30-40/month** while its infrastructure
exists (mainly the ALB and Fargate tasks) — less than project 2's
~$45-55/month, since there's no NAT Gateway this time. Still real
money, not free-tier. Plan to `terraform destroy` between active work
sessions.

## 1. Get the project onto your machine

Unzip alongside your other two projects — NOT inside either of them:

```bash
unzip -o ~/Downloads/ecs-guestbook.zip -d ~/projects
cd ~/projects/ecs-guestbook/terraform
```

## 2. Set up tfvars

```bash
cp terraform.tfvars.example terraform.tfvars
```

Defaults are fine as-is for now.

## 3. Init

```bash
export AWS_PROFILE=cloud-resume
terraform init
```

Should complete cleanly, connecting to the same S3 bucket as projects
1-2, but a new state file path (`ecs-guestbook/terraform.tfstate`).

```bash
terraform plan
```

Should show "No changes" — nothing defined yet, just confirming the
backend connects correctly.

---

## Verification checklist before moving to Phase 1

- [ ] `terraform init` completes with no errors
- [ ] `terraform plan` shows a clean empty state

Once confirmed, we'll move to **Phase 1: networking** — a simpler VPC
than project 2's, with just public and database subnet tiers (no
private "app" subnet tier, since Fargate tasks live in public subnets
this time).
