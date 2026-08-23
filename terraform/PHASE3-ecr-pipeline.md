# Phase 3 — ECR + Image Build/Push Workflow

Creates: an ECR repository, an IAM role for GitHub Actions (reusing
the account's existing OIDC provider, same pattern as project 2), and
a GitHub Actions workflow that builds the Docker image and pushes it
to ECR — entirely on GitHub's runners, never locally.

**Nothing runs yet** — ECS doesn't exist until Phase 4, so there's no
running app to serve this image. This phase proves the build/push
pipeline works in isolation.

---

## 1. Add your GitHub repo and apply

```bash
cd ~/projects/ecs-guestbook/terraform
echo 'github_repo = "kr3ativ3hustl3/ecs-guestbook"' >> terraform.tfvars
export AWS_PROFILE=cloud-resume
terraform init
terraform plan
```

Expect **5 resources to add**: the ECR repository, its lifecycle
policy, the IAM role, and its inline policy — no OIDC provider
conflict, since we're reusing the existing one via a data source.

```bash
terraform apply
```

```bash
terraform output ecr_repository_url
terraform output github_actions_role_arn
```

Copy both values.

## 2. Add the GitHub secrets

Go to your repo → **Settings → Secrets and variables → Actions → New
repository secret**:

| Secret name | Value |
|---|---|
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | the role ARN from step 1 |
| `ECR_REPOSITORY_URL` | the repository URL from step 1 |

## 3. Push the workflow and app code

```bash
cd ~/projects/ecs-guestbook
git add .github terraform app
git commit -m "Add Phase 3: ECR + image build/push workflow"
git push
```

## 4. Test it

Go to your repo's **Actions** tab — you should see "Build and Push
Image" running (triggered by the `app/` folder being pushed). Watch it
build and push. It should complete in under a minute.

Verify the image actually landed in ECR:

```bash
aws ecr describe-images --repository-name ecs-guestbook-app --profile cloud-resume --query "imageDetails[*].imageTags"
```

Should show `["latest", "<some-git-sha>"]`.

---

## Verification checklist before moving to Phase 4

- [ ] `terraform apply` succeeded (5 resources, no OIDC conflict)
- [ ] Both GitHub secrets are set
- [ ] "Build and Push Image" workflow runs successfully
- [ ] `aws ecr describe-images` shows the pushed image

Once confirmed, we'll move to **Phase 4: ECS cluster, task definition,
Fargate service, and the Application Load Balancer** — this is when
the app actually starts running and becomes reachable.
