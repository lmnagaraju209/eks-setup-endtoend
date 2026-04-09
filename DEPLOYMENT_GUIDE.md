# Deployment Guide (Terraform + Helm)

Simple, end-to-end deployment using the Terraform code in this repo and the
Helm chart in `helm/eks-setup-app`.

## Prerequisites (macOS)

- AWS CLI v2, kubectl, Helm, Terraform, Docker Desktop
- AWS credentials configured: `aws configure` or `AWS_PROFILE=<profile>`

## Step 1: Terraform — first apply with local state (no `backend.tf` yet)

Do **not** copy `backend.tf.example` to `backend.tf` until after the first successful
apply. If `backend.tf` exists first, `terraform init` talks to S3 using placeholder or
wrong region values and fails (for example HTTP 301 when `region` does not match the
bucket’s region).

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: aws_region, project_name, terraform_state_bucket_name (required), etc.
terraform init
terraform apply
```

This creates the EKS cluster, ECR repositories, and the S3 state bucket (and lock table
resources). State stays in `terraform.tfstate` on disk until you migrate.

### Move state to S3 (after the apply above succeeds)

```bash
cd terraform
terraform output terraform_state_bucket_name
terraform output aws_region
```

Copy the example backend and paste **exactly** what the outputs show (same bucket name
and **same region as `aws_region` in terraform.tfvars** — not a different region).

```bash
cp backend.tf.example backend.tf
# Edit backend.tf: set bucket and region from terraform output (remove REPLACE_ME_*)
terraform init -migrate-state
```

If `terraform output` says there is no state file, you are in the wrong directory,
apply never succeeded, or a broken `backend.tf` prevents init — temporarily rename
`backend.tf`, run `terraform init -backend=false`, then run the output commands again.

## Step 3: Configure kubectl
```bash
terraform output configure_kubectl
```

Verify:
```bash
kubectl get nodes
```

## Step 4: Build and push images to ECR

Get ECR URLs:
```bash
terraform output ecr_backend_repository_url
terraform output ecr_frontend_repository_url
```

Login to ECR:
```bash
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

Build and push backend:
```bash
cd services/backend
docker build -t <backend-repo-url>:latest .
docker push <backend-repo-url>:latest
```

Build and push frontend:
```bash
cd services/frontend
docker build -t <frontend-repo-url>:latest .
docker push <frontend-repo-url>:latest
```

## Step 5: Deploy with Helm

```bash
helm upgrade --install eks-setup-app ./helm/eks-setup-app \
  --set backend.image.repository=<backend-repo-url> \
  --set backend.image.tag=latest \
  --set frontend.image.repository=<frontend-repo-url> \
  --set frontend.image.tag=latest
```

Check status:
```bash
kubectl get pods
kubectl get svc
```

## Step 6: Access the application

```bash
kubectl get svc
# Look for eks-setup-app-frontend (or your Helm release name)
```

## Troubleshooting

```bash
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

## Optional: Enable add-ons on second apply

After the first successful apply, you can enable optional features and run
Terraform again:

- `enable_public_domain_ingress = true` (set `route53_zone_name`, `application_host`)
- `enable_argocd = true`
- `enable_monitoring = true`
- `enable_logging = true`
- `enable_external_secrets = true`

Then run:
```bash
terraform apply
```

## Safe Terraform Re-Apply / Destroy

- Always run Terraform from the same folder and keep the state file safe.
- Wait for `terraform destroy` to finish before running `terraform apply` again.
- Avoid deleting AWS resources manually outside Terraform.

If you plan to run Terraform many times, use an S3 backend for the state file.

## Updates

After pushing new images:
```bash
kubectl rollout restart deployment/eks-setup-app-backend
kubectl rollout restart deployment/eks-setup-app-frontend
```

## Cleanup

```bash
helm uninstall eks-setup-app
cd terraform
terraform destroy
```

