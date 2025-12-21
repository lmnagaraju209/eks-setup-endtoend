# ECR Hardcoded Repository Names Setup

## ✅ Changes Made

ECR repository names are now **hardcoded** to use "taskmanager" prefix for easier GitHub Actions configuration.

### Phase 1 (Terraform) - `terraform/ecr.tf`

**Repository Names Created**:
- **Backend**: `taskmanager-backend`
- **Frontend**: `taskmanager-frontend`

These are hardcoded (no longer use `${var.project_name}`), so they're always the same regardless of your project name variable.

### Phase 2/4 (GitHub Actions) - `.github/workflows/deploy.yml`

**Hardcoded Values**:
```yaml
env:
  ECR_BACKEND_REPOSITORY: taskmanager-backend
  ECR_FRONTEND_REPOSITORY: taskmanager-frontend
```

No GitHub Variables needed for ECR repository names anymore! Just need:
- `AWS_ACCOUNT_ID`
- `AWS_REGION`

---

## What Gets Created

When you run `terraform apply` in Phase 1:

1. **ECR Repository**: `taskmanager-backend`
   - Image scanning enabled
   - Lifecycle policy: keeps last 30 images

2. **ECR Repository**: `taskmanager-frontend`
   - Image scanning enabled
   - Lifecycle policy: keeps last 30 images

3. **IAM Permissions**: GitHub Actions OIDC role gets access to push/pull from these repositories

---

## GitHub Actions Workflow

The workflow now uses hardcoded repository names:

```yaml
# Build and push backend
docker build -t $ECR_REGISTRY/taskmanager-backend:$IMAGE_TAG ./services/backend
docker push $ECR_REGISTRY/taskmanager-backend:$IMAGE_TAG

# Build and push frontend
docker build -t $ECR_REGISTRY/taskmanager-frontend:$IMAGE_TAG ./services/frontend
docker push $ECR_REGISTRY/taskmanager-frontend:$IMAGE_TAG
```

---

## Required GitHub Variables (Reduced!)

You only need these 2 variables now (no ECR repository names needed):

1. Go to **Settings → Secrets and variables → Actions → Variables**
2. Add:
   - `AWS_ACCOUNT_ID` (example: `123456789012`)
   - `AWS_REGION` (example: `us-east-2`)

**How to get these values**:
```bash
cd terraform
terraform output aws_account_id
terraform output aws_region
```

---

## Verification

After `terraform apply`, verify repositories exist:

```bash
# List repositories
aws ecr describe-repositories --region us-east-2 | grep taskmanager

# Or check via Terraform outputs
terraform output ecr_backend_repository_name  # Should show: taskmanager-backend
terraform output ecr_frontend_repository_name # Should show: taskmanager-frontend
terraform output ecr_backend_repository_url
terraform output ecr_frontend_repository_url
```

---

## Summary

✅ **ECR repositories**: Hardcoded as `taskmanager-backend` and `taskmanager-frontend`  
✅ **GitHub Actions**: Uses hardcoded names directly (no variables needed)  
✅ **Simplified setup**: Only 2 GitHub variables needed (AWS_ACCOUNT_ID, AWS_REGION)  
✅ **Consistent naming**: Same repository names every time, regardless of project_name variable

**Ready to use!** When you push code, GitHub Actions will automatically push to these hardcoded ECR repositories. 🚀

