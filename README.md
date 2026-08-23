# ECS Guestbook — Containerized Three-Tier AWS Architecture

The same guestbook app from [project 2](https://github.com/kr3ativ3hustl3/vpc-guestbook),
containerized and deployed on ECS Fargate instead of raw EC2 — a
direct architectural comparison: same application, two different
compute models.

This is project 3 in a portfolio series:
- [Project 1](https://github.com/kr3ativ3hustl3/cloud-resume-challenge) — serverless (Lambda, DynamoDB, API Gateway)
- [Project 2](https://github.com/kr3ativ3hustl3/vpc-guestbook) — traditional (EC2, Auto Scaling Group, VPC)
- **Project 3 (this one)** — containers (ECS Fargate, ECR, Docker)

**Status:** 🚧 In progress — Phase 1 of 6 complete (networking: VPC,
public + database subnets, no NAT gateway).

## Architecture

```
                         Internet
                            │
                    ┌───────▼────────┐
                    │  Application    │   (public subnets, 2 AZs)
                    │  Load Balancer  │
                    └───────┬────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
      ┌───────▼───────┐           ┌───────▼───────┐
      │  Fargate task  │           │  Fargate task  │   (public subnets,
      │  (guestbook)   │           │  (guestbook)   │    public IP, no NAT)
      └───────┬───────┘           └───────┬───────┘
              │                           │
              └─────────────┬─────────────┘
                             │
                     ┌───────▼────────┐
                     │  RDS Postgres   │   (isolated subnet, no internet)
                     └────────────────┘
```

**Key differences from project 2, all deliberate:**
- Reuses the same guestbook app — containerized, not rewritten
- No NAT Gateway — Fargate tasks sit in public subnets with locked-
  down security groups instead, saving ~$32/month versus project 2
- DB credentials injected via ECS task definition `secrets` from SSM
  Parameter Store — no manual fetch script needed at boot
- All Docker builds happen in GitHub Actions, never locally — this
  dev machine's older macOS can't run current Docker Desktop versions

## Tech stack

- **Containers:** Docker, ECR, ECS Fargate
- **Networking:** VPC, public + database subnets across 2 AZs (no NAT)
- **Load balancing:** Application Load Balancer
- **Database:** RDS Postgres, isolated subnet
- **Secrets:** SSM Parameter Store, injected natively via ECS task definition
- **IaC:** Terraform, reusing the state backend from projects 1-2
- **CI/CD:** GitHub Actions — builds the image, pushes to ECR, updates the ECS service

## Repo structure

```
ecs-guestbook/
├── docs/                    # architecture notes, troubleshooting log
├── app/guestbook/           # Flask app + Dockerfile
└── terraform/
    └── modules/             # networking, database, ecr, ecs
```

## Build log (phases)

- [x] **Phase 0** — Project scaffold, Terraform state (reusing projects 1-2's backend)
- [x] **Phase 1** — Networking: VPC, public + database subnets. See [`terraform/PHASE1-networking.md`](terraform/PHASE1-networking.md).
- [ ] **Phase 2** — Database: RDS Postgres
- [ ] **Phase 3** — ECR + GitHub OIDC + image build/push workflow
- [ ] **Phase 4** — ECS cluster, task definition, Fargate service, ALB
- [ ] **Phase 5** — CI/CD: auto-deploy on image push
- [ ] **Phase 6** — Final polish & write-up

## Troubleshooting

Real issues hit while building this are logged in
[`docs/troubleshooting.md`](docs/troubleshooting.md).
