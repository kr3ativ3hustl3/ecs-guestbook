# Architecture Notes

## Overview

The project 2 guestbook app, containerized and deployed on ECS
Fargate — same application logic, different compute model. Built as a
direct comparison point: project 2 proves EC2/ASG/VPC fundamentals,
this project proves containers on top of the same fundamentals.

## Design decisions & tradeoffs

### Reusing the state backend from projects 1-2, with a separate key
Same pattern as project 2 reusing project 1's backend — one S3 bucket
and DynamoDB table serve all three projects' Terraform state, each
isolated by its own `key` (state file path). No new account-level
setup required.

### ECS Fargate, not EC2-backed ECS
ECS supports two launch types: EC2 (you manage the underlying
instances yourself) and Fargate (AWS manages the compute, you just
specify how much CPU/memory each task needs). Fargate costs more per
vCPU-hour than an equivalent EC2 instance, but removes an entire
category of operational work — no AMIs, no patching, no Auto Scaling
Group for the hosts themselves. For a project specifically meant to
demonstrate containers (not EC2 management, which project 2 already
covers), Fargate is the more focused choice.

### No local Docker — all builds happen in GitHub Actions
Docker Desktop's current versions require a newer macOS than this
project's development machine has (a recurring theme across these
three projects). Rather than fight that, every `docker build` and
`docker push` happens inside GitHub Actions' hosted runners, which
have Docker pre-installed and fully working. This also happens to be
good practice regardless of local tooling — a real CI/CD pipeline
builds images in a clean, consistent environment, not on whichever
laptop happens to run the command.

### No NAT Gateway — Fargate tasks in public subnets instead
Project 2's single biggest recurring cost was the NAT Gateway (~$32/
month), needed so private-subnet EC2 instances could reach the
internet (for OS updates, pulling packages, etc.). Fargate tasks in
this project sit in public subnets with automatically-assigned public
IPs, but their security group only accepts inbound traffic from the
ALB — nothing else. This means no NAT Gateway is needed for tasks to
pull their container image from ECR or reach the internet generally,
while remaining just as unreachable from the internet directly as
project 2's private-subnet EC2 instances were. This is a genuine,
explainable cost/security tradeoff worth being able to discuss: public
IP assignment is not the same thing as being open to inbound traffic
from the internet — those are controlled independently (IP assignment
vs. security group rules).

### DB credentials via ECS task definition `secrets`, not a manual fetch script
Project 2's EC2 instances fetched DB credentials from SSM Parameter
Store via a shell script at boot. ECS task definitions support a
native `secrets` field that injects SSM parameters directly as
environment variables before the container even starts — no
in-container fetch logic needed at all. This is both simpler and a
demonstration of a container-native pattern that has no real EC2
equivalent.

### Mutable ECR tags with an explicit "latest" + git-sha pair, not immutable per-build tags
The more production-grade pattern tags every build with a unique
identifier (e.g. the git commit SHA) and updates the ECS task
definition to reference that exact tag on every deploy — giving a
precise audit trail and trivial rollback, enforced by making tags
IMMUTABLE so nothing can silently overwrite a previous build. This
project uses the simpler mutable "latest" tag (with the git SHA also
pushed alongside it, for reference) and explicitly tells ECS to
redeploy after each push, rather than updating the task definition
each time. Less machinery, a real tradeoff worth naming directly if
asked — not the "best" answer, but an honest, deliberate one.

### Load balancer module intentionally knows nothing about ECS
Connecting the ECS service to the target group needs the target
group's ARN inside the service's required `load_balancer` block —
there's no separate "attachment" resource for this the way project 2
used `aws_autoscaling_attachment` to solve the same category of
problem for an Auto Scaling Group. Since that inline block can't be
avoided, the only way to prevent a circular dependency between the
two modules is to make the dependency strictly one-directional: the
load-balancer module takes no input from the ecs module at all, and
the ecs module takes the load-balancer module's outputs (target group
ARN, ALB security group ID) as inputs. A module-level `depends_on`
on the `ecs` module call in root `main.tf` (rather than inside the
module itself) additionally guarantees the ALB's listener exists
before ECS tries to register tasks against its target group — a
dependency that can't be expressed through normal Terraform reference
chains, since a child module can't see another module's resources
directly, only its declared outputs.

### Task execution role, not a separate task role
ECS distinguishes between an execution role (used by the ECS agent
itself — pulling the image, writing logs, and fetching any `secrets`
referenced in the task definition) and a task role (used by the
application code at runtime for its own AWS API calls). This app
never calls AWS APIs directly — it only receives database credentials
as plain environment variables — so only an execution role is needed.
A common point of confusion: secrets injection permissions belong on
the execution role, not a task role, even though "the app needs
access to its secrets" sounds like an application-facing (task role)
concern by name alone.

## Cost breakdown (expected)

| Service | Free tier | Expected usage | Expected cost |
|---|---|---|---|
| VPC, subnets, route tables | Always free | N/A | $0 |
| Application Load Balancer | **Not free** | 1 ALB | ~$16-20/mo |
| ECS Fargate | No free tier | 2 tasks, 0.25 vCPU / 0.5GB each | ~$15-20/mo |
| ECR | 500MB free (12mo) | 1 small image | $0 |
| RDS (db.t3.micro) | 750 hrs/mo (12mo) | 1 instance | $0 (free tier, first 12mo) |

**No NAT Gateway this time** — the single biggest cost saver versus
project 2. Expect roughly **$30-40/month total** while this runs,
noticeably less than project 2's ~$45-55/month, primarily because of
the NAT Gateway removal (Fargate itself costs somewhat more than the
equivalent EC2 instances would, but not enough to offset that saving).

## Security posture (running list, updated per phase)

- Phase 0: Terraform state reuses the existing encrypted, versioned,
  private S3 backend from projects 1-2.
- Phase 1: database subnets have zero route to the internet, same as
  project 2. Public subnets exist for the ALB and (later) Fargate
  tasks — no NAT Gateway needed since nothing lives in a private,
  NAT-dependent subnet this time.
- Phase 2: RDS security group created with zero inbound rules — the
  database is unreachable from anything until Phase 4 explicitly
  grants ECS task access. Not publicly accessible; sits in subnets
  with no internet route at all.
- Phase 3: GitHub Actions authenticates via the account's existing
  OIDC provider (reused, not recreated), short-lived tokens, no static
  AWS credentials in GitHub. Its IAM role can push images to exactly
  one ECR repository and nothing else — cannot touch any other AWS
  resource, including this project's own database or networking.
  Container images scanned for vulnerabilities on every push.
- Phase 4: only the ALB accepts traffic from the public internet
  (port 80 only). ECS tasks accept traffic ONLY from the ALB's
  security group, on the app port only — despite having public IPs,
  they're not reachable directly from the internet. RDS accepts
  traffic ONLY from the ECS tasks' security group. The execution
  role's SSM/KMS permissions are scoped to exactly this project's
  parameter path and to KMS calls made specifically via the SSM
  service — not broad decrypt access.
- Phase 5: the same GitHub Actions role from Phase 3 gains exactly
  one more narrowly-scoped permission — redeploying this one specific
  ECS service — rather than a new, separate role. Still cannot touch
  networking, the database, or any other AWS resource.

## Observability posture (running list, updated per phase)

- (To be added in a later phase.)
