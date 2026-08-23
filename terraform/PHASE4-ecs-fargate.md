# Phase 4 — ECS, Fargate Service, and Load Balancer

Creates: the ALB (load-balancer module), then the ECS cluster, task
definition, Fargate service, IAM execution role, SSM parameters, and
the security group rules connecting everything (ecs module).

**This is the payoff phase** — the containerized app becomes reachable
and fully functional, database included, for the first time.

---

## 1. Plan and apply

```bash
cd ~/projects/ecs-guestbook/terraform
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect roughly **23 resources to add** across both new modules: the
ALB security group, ALB, target group, listener (load-balancer
module); and the ECS cluster, log group, 5 SSM parameters, IAM role +
attachment + inline policy, ECS tasks security group, 2 security
group rules, task definition, and service (ecs module).

```bash
terraform apply
```

Give it a few minutes — ECS needs to launch the Fargate tasks and
they need to pass their first health check before the service
stabilizes.

## 2. Get the site URL

```bash
terraform output site_url
```

Open that in a browser. **It can take 2-4 minutes after apply
finishes** for tasks to launch, pass health checks, and register —
if you see a 503 immediately, that's normal, wait and refresh.

## 3. Verify service and task health

```bash
aws ecs describe-services --cluster ecs-guestbook-cluster --services ecs-guestbook-service --profile cloud-resume --query "services[0].[status,runningCount,desiredCount]"
```

Should show `["ACTIVE", 2, 2]` once both tasks are running.

```bash
TG_ARN=$(aws elbv2 describe-target-groups --names ecs-guestbook-tg --profile cloud-resume --query "TargetGroups[0].TargetGroupArn" --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN --profile cloud-resume --query "TargetHealthDescriptions[*].TargetHealth.State"
```

Should show `["healthy", "healthy"]`.

## 4. Check container logs (if anything looks wrong)

```bash
aws logs tail /ecs/ecs-guestbook --profile cloud-resume --follow
```

This streams the actual container logs — useful for diagnosing
anything from a bad DB connection to a Python startup error.

## 5. Actually use the app

Open the site URL and submit a guestbook entry. Refresh — it should
appear, proving the full chain: browser → ALB → Fargate task → RDS.

---

## Verification checklist — core architecture complete

- [ ] `terraform apply` completed with no errors
- [ ] `terraform output site_url` returns a real ALB DNS name
- [ ] ECS service shows `runningCount == desiredCount == 2`
- [ ] Both targets show `healthy`
- [ ] Submitting the guestbook form actually saves and displays an entry

Once confirmed, this is functionally a complete containerized
three-tier architecture. **Phase 5 (CI/CD auto-deploy) and Phase 6
(final write-up) are refinements from here.**

**Cost reminder:** with ECS + ALB now running, you're at roughly
**$30-40/month total** (no NAT Gateway this time, unlike project 2's
~$45-55/month). `terraform destroy` when not actively using it —
everything rebuilds cleanly from the same Terraform.
