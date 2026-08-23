# Phase 5 — CI/CD Auto-Deploy

Adds: an ECS deploy permission to the existing GitHub Actions role,
and two new steps to the build/push workflow — force a new ECS
deployment after pushing the image, then wait for the service to
stabilize before the workflow reports success.

How it works: ECS's task definition always points at the `:latest`
tag, so pushing a new image alone doesn't make running tasks pick it
up automatically. `aws ecs update-service --force-new-deployment`
tells ECS to replace running tasks with new ones — which pull
whatever `:latest` currently points to.

---

## 1. Apply the updated IAM permissions

```bash
cd ~/projects/ecs-guestbook/terraform
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect **1 resource to add** — the new `ecs_deploy` inline policy on
the existing GitHub Actions role. Nothing else should change.

```bash
terraform apply
```

## 2. Push the updated workflow

```bash
cd ~/projects/ecs-guestbook
git add .github terraform
git commit -m "Phase 5: CI/CD auto-deploy on image push"
git push
```

This alone won't trigger a run (it doesn't touch `app/**`).

## 3. Test the full pipeline

Make a small app change:

```bash
echo "# CI/CD auto-deploy test" >> app/guestbook/app.py
git add app/guestbook/app.py
git commit -m "Test full CI/CD pipeline"
git push
```

Watch the **Actions** tab — "Build, Push, and Deploy" should run all
four steps: build, push, trigger deploy, wait for stability. The wait
step can take a couple of minutes, since it polls until ECS reports
the new tasks healthy.

## 4. Verify the live site actually updated

```bash
curl -s http://<your-alb-dns-name>/ | grep "three-tier"
```

Should now reflect whatever the app currently says — confirming the
running site picked up the new deployment, not just that the image
exists in ECR.

---

## Verification checklist

- [ ] `terraform apply` succeeded (1 resource: the new deploy policy)
- [ ] "Build, Push, and Deploy" completes all 4 steps successfully
- [ ] The live site reflects the pushed change afterward

Once confirmed, we'll move to **Phase 6: final write-up** — polishing
the README into a finished portfolio piece, same as the other two
projects.
