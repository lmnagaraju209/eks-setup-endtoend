# AWS Account Configuration

This document contains your AWS account configuration for deployment.

## AWS Account Information

- **AWS Account ID**: `343218219153`
- **Repository**: `https://github.com/lmnagaraju209/eks-setup-endtoend.git`
- **GitHub Username**: `lmnagaraju209`

## ECR Repository URLs

With this account ID, your ECR repository URLs will be:

- **Backend**: `343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-backend`
- **Frontend**: `343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-frontend`

Replace `<region>` with your AWS region (e.g., `us-east-1`, `us-east-2`).

## GitHub Actions Configuration

Set these variables in **GitHub → Settings → Secrets and variables → Actions → Variables**:

| Variable | Value | Description |
|----------|-------|-------------|
| `AWS_ACCOUNT_ID` | `343218219153` | Your AWS account ID |
| `AWS_REGION` | `<your-region>` | AWS region (e.g., `us-east-1`, `us-east-2`) |

### Example GitHub Actions Variable Setup

1. Go to: https://github.com/lmnagaraju209/eks-setup-endtoend/settings/variables/actions
2. Click **New repository variable**
3. Add:
   - **Name**: `AWS_ACCOUNT_ID`
   - **Value**: `343218219153`
4. Click **Add variable**
5. Repeat for `AWS_REGION` with your region value

## Terraform Configuration

When running Terraform, the account ID will be automatically detected. However, you can verify it:

```bash
cd terraform
terraform apply
terraform output aws_account_id  # Should show: 343218219153
```

## ECR Login Command

```bash
# Replace <region> with your AWS region
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin 343218219153.dkr.ecr.<region>.amazonaws.com
```

## Docker Image Push Commands

```bash
# Backend
docker tag <local-image> 343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-backend:latest
docker push 343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-backend:latest

# Frontend
docker tag <local-image> 343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-frontend:latest
docker push 343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-frontend:latest
```

## Helm Values

When Helm values are updated by GitHub Actions, they will use:

```yaml
backend:
  image:
    repository: 343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-backend
    tag: <commit-sha>

frontend:
  image:
    repository: 343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-frontend
    tag: <commit-sha>
```

## Verification

Verify your account ID is correct:

```bash
# Using AWS CLI
aws sts get-caller-identity

# Should show:
# {
#     "UserId": "...",
#     "Account": "343218219153",
#     "Arn": "arn:aws:iam::343218219153:user/..."
# }
```

## Next Steps

1. ✅ Set `AWS_ACCOUNT_ID = 343218219153` in GitHub Actions variables
2. ✅ Set `AWS_REGION` in GitHub Actions variables
3. ✅ Run `terraform apply` to create infrastructure
4. ✅ Configure ArgoCD with GitHub repository access
5. ✅ Push code to trigger CI/CD pipeline

