# Terraform Apply Checklist

## Pre-Apply Checklist

✅ **Configuration Verified**:
- AWS Account ID: `343218219153`
- Region: `us-east-2`
- GitHub Org: `lmnagaraju209`
- GitHub Repo: `eks-setup-endtoend`

✅ **Changes Detected**:
- ECR repositories renamed: `demo-backend` → `taskmanager-backend`, `demo-frontend` → `taskmanager-frontend`
- ArgoCD will be installed
- Monitoring stack will be installed
- External Secrets Operator will be installed
- Node group will be recreated

## After Apply - Required Actions

### 1. Set GitHub Actions Variables

Go to: https://github.com/lmnagaraju209/eks-setup-endtoend/settings/variables/actions

Add these variables:
- `AWS_ACCOUNT_ID` = `343218219153`
- `AWS_REGION` = `us-east-2`

### 2. Set GitHub Actions Secret

Get the OIDC role ARN:
```bash
cd terraform
terraform output github_actions_role_arn
```

Then add in GitHub → Settings → Secrets:
- `AWS_ROLE_TO_ASSUME` = `<arn-from-output>`

### 3. Configure ArgoCD Repository Access

Get ArgoCD password:
```bash
terraform output -raw argocd_admin_password
```

Then configure ArgoCD to access GitHub repository (see `ARGOCD_SETUP_INSTRUCTIONS.md`).

