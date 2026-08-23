# ECS Guestbook — Containerized Three-Tier AWS Architecture

The same guestbook app from [project 2](https://github.com/kr3ativ3hustl3/vpc-guestbook),
containerized and deployed on ECS Fargate instead of raw EC2 — a
direct architectural comparison: same application, two different
compute models.

This is project 3 in a portfolio series:
- [Project 1](https://github.com/kr3ativ3hustl3/cloud-resume-challenge) — serverless (Lambda, DynamoDB, API Gateway)
- [Project 2](https://github.com/kr3ativ3hustl3/vpc-guestbook) — traditional (EC2, Auto Scaling Group, VPC)
- **Project 3 (this one)** — containers (ECS Fargate, ECR, Docker)

**Status:** ✅ Complete (Phases 0-6).

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

   GitHub Actions: docker build → push to ECR → force ECS redeploy
   → wait for stability
```

Full reasoning behind every architectural decision — including the
circular-dependency puzzle ECS's inline `load_balancer` block creates,
and how it differs from project 2's `aws_autoscaling_attachment`
solution — in [`docs/architecture.md`](docs/architecture.md).

## Tech stack

- **Containers:** Docker, ECR, ECS Fargate
- **Networking:** VPC, public + database subnets across 2 AZs, no NAT Gateway
- **Load balancing:** Application Load Balancer, target group (IP-based, for Fargate)
- **Database:** RDS Postgres, isolated subnet, security-group-scoped access only
- **Secrets:** SSM Parameter Store, injected natively via ECS task definition `secrets`
- **IaC:** Terraform, modular (networking, database, ecr, github-cicd, load-balancer, ecs)
- **CI/CD:** GitHub Actions — build, push, force ECS redeploy, wait for stability — no local Docker required

## What this project actually demonstrates

- **A genuinely different circular-dependency fix than project 2** —
  ECS has no equivalent to `aws_autoscaling_attachment`, since the
  load balancer connection is a required inline block on the service
  itself. The fix here is architectural: keep the dependency strictly
  one-directional between modules, and use a module-level `depends_on`
  to guarantee correct resource ordering across module boundaries.
- **A non-obvious ECS/IAM distinction found and applied correctly**:
  secrets injected via a task definition are fetched by the *execution*
  role, not a *task* role — an easy detail to get backwards by name
  alone.
- **Proactive reuse of hard-won lessons from projects 1-2** — the
  GitHub OIDC subject-claim wildcard fix, the ASCII-only security
  group description rule, and the "some AWS actions need `Resource:
  "*"`" IAM nuance were all applied correctly from the first attempt
  in this project, not rediscovered.
- **A direct cost and architecture comparison with project 2** — same
  app, ~$15/month cheaper per month, no NAT Gateway, genuinely
  different operational model (no OS patching, no Auto Scaling Group
  for hosts) — a real, explainable "here's what changes when you move
  to containers" story.

## Cost

Roughly **$30-40/month** while running — no NAT Gateway this time,
the single biggest cost difference from project 2's ~$45-55/month.
Full breakdown in [`docs/architecture.md`](docs/architecture.md).
`terraform destroy` between active work sessions; full rebuild takes
about 10-15 minutes (RDS is still the slow part, ECS/ALB are fast).

## Repo structure

```
ecs-guestbook/
├── docs/                    # architecture decisions, troubleshooting log
├── app/guestbook/           # Flask app + Dockerfile
├── terraform/
│   └── modules/             # networking, database, ecr, github-cicd, load-balancer, ecs
└── .github/workflows/       # build, push, and deploy pipeline
```

## Build log (phases)

- [x] **Phase 0** — Project scaffold, Terraform state (reusing projects 1-2's backend)
- [x] **Phase 1** — Networking: VPC, public + database subnets, no NAT
- [x] **Phase 2** — Database: RDS Postgres
- [x] **Phase 3** — ECR + GitHub OIDC + image build/push workflow
- [x] **Phase 4** — ECS cluster, task definition, Fargate service, ALB
- [x] **Phase 5** — CI/CD auto-deploy on image push
- [x] **Phase 6** — Final polish & write-up (this README)

Detailed walkthroughs for each phase live alongside the Terraform
code: `terraform/PHASE0-setup.md` through `PHASE5-cicd.md`.

## Troubleshooting

Every real issue hit during the build — with root cause and fix — is
logged in [`docs/troubleshooting.md`](docs/troubleshooting.md).

## Security notes

- No local Docker credentials or long-lived AWS keys anywhere — all
  builds and deploys authenticate via GitHub's OIDC provider (reused
  from project 2, not recreated)
- Container images scanned for vulnerabilities on every push
- Every tier's security group accepts traffic ONLY from the specific
  tier in front of it
- IAM roles scoped tightly per responsibility: the CI/CD role can push
  to one ECR repo and redeploy one ECS service; the ECS execution role
  can read exactly one SSM parameter path
- Full posture, updated per phase, in [`docs/architecture.md`](docs/architecture.md)
