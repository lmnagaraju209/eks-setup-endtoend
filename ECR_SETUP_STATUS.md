# ECR Repositories Setup Status

## ✅ ECR Repositories Already Created in Phase 1 (Terraform)

Good news! **ECR repositories are already created as part of Phase 1 infrastructure**.

### Current Setup

**Terraform File**: `terraform/ecr.tf`

**Repositories Created**:
1. **Backend**: `{project_name}-backend`
2. **Frontend**: `{project_name}-frontend`

**Example**: If `project_name = "demo"`, repositories are:
- `demo-backend`
- `demo-frontend`

### Features Included

✅ **Image Scanning**: Automatic security scanning on push
✅ **Lifecycle Policy**: Keeps last 30 images (deletes older ones automatically)
✅ **Tags**: Proper resource tagging

### Terraform Outputs

After `terraform apply`, you can get repository information:

```bash
# Get repository URLs (full ECR URLs)
terraform output ecr_backend_repository_url
terraform output ecr_frontend_repository_url

# Get repository names (just the names)
terraform output ecr_backend_repository_name
terraform output ecr_frontend_repository_name
```

**Example Output**:
```
ecr_backend_repository_name = "demo-backend"
ecr_backend_repository_url = "123456789012.dkr.ecr.us-east-2.amazonaws.com/demo-backend"
```

---

## How It's Used in Phase 2/Phase 4

### GitHub Actions Workflow (`.github/workflows/deploy.yml`)

The workflow uses GitHub Variables to get ECR repository names:

```yaml
env:
  ECR_BACKEND_REPOSITORY: ${{ vars.ECR_BACKEND_REPOSITORY }}
  ECR_FRONTEND_REPOSITORY: ${{ vars.ECR_FRONTEND_REPOSITORY }}
```

### Required GitHub Variables

You need to set these in GitHub Repository Settings → Secrets and variables → Actions → Variables:

| Variable Name | Value (Example) | How to Get |
|--------------|-----------------|------------|
| `ECR_BACKEND_REPOSITORY` | `demo-backend` | `terraform output ecr_backend_repository_name` |
| `ECR_FRONTEND_REPOSITORY` | `demo-frontend` | `terraform output ecr_frontend_repository_name` |
| `AWS_REGION` | `us-east-2` | `terraform output aws_region` |
| `AWS_ACCOUNT_ID` | `123456789012` | `terraform output aws_account_id` |

---

## Setup Steps

### 1. Run Terraform Apply (Phase 1)

```bash
cd terraform
terraform apply
```

This creates the ECR repositories.

### 2. Get Repository Names

```bash
# Get all ECR-related outputs
terraform output ecr_backend_repository_name
terraform output ecr_frontend_repository_name
terraform output aws_account_id
terraform output aws_region
```

### 3. Configure GitHub Variables

Go to your GitHub repository:
1. Settings → Secrets and variables → Actions
2. Click "Variables" tab
3. Add these variables:
   - `ECR_BACKEND_REPOSITORY` = value from `terraform output ecr_backend_repository_name`
   - `ECR_FRONTEND_REPOSITORY` = value from `terraform output ecr_frontend_repository_name`
   - `AWS_REGION` = value from `terraform output aws_region`
   - `AWS_ACCOUNT_ID` = value from `terraform output aws_account_id`

### 4. Push Code (Phase 2/Phase 4)

When you push code:
1. GitHub Actions runs
2. Builds Docker images
3. Pushes to ECR repositories created in Phase 1
4. Updates Helm chart values
5. ArgoCD syncs and deploys to EKS

---

## Repository Naming Convention

Repositories are named based on `project_name` variable in `terraform.tfvars`:

- Backend: `{project_name}-backend`
- Frontend: `{project_name}-frontend`

**Examples**:
- If `project_name = "demo"` → `demo-backend`, `demo-frontend`
- If `project_name = "my-app"` → `my-app-backend`, `my-app-frontend`

---

## Verification

After Terraform apply, verify repositories exist:

```bash
# List ECR repositories
aws ecr describe-repositories --region us-east-2

# Or check via Terraform outputs
terraform output ecr_backend_repository_url
terraform output ecr_frontend_repository_url
```

---

## Summary

✅ **ECR repositories ARE created in Phase 1** (already done!)
✅ **Repositories are ready to use in Phase 2/Phase 4**
✅ **Just need to set GitHub Variables** with the repository names
✅ **Everything is connected** - GitHub Actions will push to these repos

**No changes needed** - the setup is already correct! 🎉

