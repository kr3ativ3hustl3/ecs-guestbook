# Phase 1 — Networking

Creates: a VPC with public and database subnets across 2 Availability
Zones, and an Internet Gateway. No NAT Gateway this time — see
docs/architecture.md for why.

---

## 1. Review and apply

```bash
cd ~/projects/ecs-guestbook/terraform
export AWS_PROFILE=cloud-resume
terraform plan
```

Expect **9 resources to add**: 1 VPC, 1 Internet Gateway, 4 subnets (2
public, 2 database), 2 route tables, 2 route table associations —
noticeably fewer than project 2's 19, since there's no NAT Gateway,
Elastic IP, or private-subnet route table this time.

```bash
terraform apply
```

This should be fast — no NAT Gateway means no multi-minute wait.

## 2. Verify

```bash
terraform output vpc_id
terraform output public_subnet_ids
terraform output database_subnet_ids
```

All three should return real values.

---

## Verification checklist before moving to Phase 2

- [ ] `terraform apply` completed with 9 resources added, no errors
- [ ] All 3 outputs return real IDs

Once confirmed, we'll move to **Phase 2: the database tier** — RDS
Postgres in the isolated database subnets, same locked-down pattern
as project 2.
