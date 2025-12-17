# Phase 4: CI/CD (GitHub Actions)

This repo uses GitHub Actions to:

- build + test the backend/frontend
- build + push Docker images to Amazon ECR
- update Helm chart image tags (GitOps-friendly)

## Required GitHub Variables

Create these in **Repo Settings → Secrets and variables → Actions → Variables**:

- `AWS_ACCOUNT_ID`: your AWS account ID (12 digits)
- `AWS_REGION`: your AWS region (example: `us-east-1`)
- `ECR_BACKEND_REPOSITORY`: ECR repo name for backend (Terraform creates `${project_name}-backend`)
- `ECR_FRONTEND_REPOSITORY`: ECR repo name for frontend (Terraform creates `${project_name}-frontend`)

Tip: after `terraform apply`, you can copy these from:

```bash
cd terraform
terraform output aws_account_id
terraform output aws_region
terraform output ecr_backend_repository_name
terraform output ecr_frontend_repository_name
```

## Required GitHub Secrets

Create these in **Repo Settings → Secrets and variables → Actions → Secrets**.

### Option A (recommended): OIDC role assumption

- `AWS_ROLE_TO_ASSUME`: IAM role ARN GitHub Actions can assume

You can copy it from Terraform after `apply`:

```bash
cd terraform
terraform output github_actions_role_arn
```

### Option B: Access keys

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## What the workflow does

Workflow: `.github/workflows/deploy.yml`

- On PRs to `main`: runs tests, builds images (still pushes to ECR if credentials exist)
- On pushes to `main`: pushes images tagged with the commit SHA and `latest`, then commits a Helm values bump:
  - `helm/eks-setup-app/values.yaml` gets updated to:
    - `backend.image.repository = <account>.dkr.ecr.<region>.amazonaws.com/backend`
    - `backend.image.tag = <git sha>`
    - `frontend.image.repository = <account>.dkr.ecr.<region>.amazonaws.com/frontend`
    - `frontend.image.tag = <git sha>`

## Deploying with Helm (manual)

Once images are pushed and values updated, deploy from your machine:

```bash
helm upgrade --install eks-setup-app ./helm/eks-setup-app -n default --create-namespace
```

If you want Ingress/HPA/IRSA, set values (or provide an env-specific values file).


