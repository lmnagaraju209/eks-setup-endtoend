# GitHub Actions Setup Guide

Complete setup guide for GitHub Actions CI/CD pipeline with your AWS account.

## Your Configuration

- **AWS Account ID**: `343218219153`
- **GitHub Repository**: `lmnagaraju209/eks-setup-endtoend`
- **GitHub Username**: `lmnagaraju209`

## Step 1: Configure GitHub Variables

Go to: **https://github.com/lmnagaraju209/eks-setup-endtoend/settings/variables/actions**

### Add Repository Variables

Click **"New repository variable"** and add:

#### Variable 1: AWS_ACCOUNT_ID
- **Name**: `AWS_ACCOUNT_ID`
- **Value**: `343218219153`
- **Description**: AWS account ID for ECR

#### Variable 2: AWS_REGION
- **Name**: `AWS_REGION`
- **Value**: `us-east-2` (or your region if different)
- **Description**: AWS region where resources are deployed

## Step 2: Configure GitHub Secrets

Go to: **https://github.com/lmnagaraju209/eks-setup-endtoend/settings/secrets/actions**

### Option A: OIDC Role (Recommended - No Access Keys Needed)

After running `terraform apply`, get the role ARN:

```bash
cd terraform
terraform output github_actions_role_arn
```

Then add secret:
- **Name**: `AWS_ROLE_TO_ASSUME`
- **Value**: `<arn-from-terraform-output>`
  - Example: `arn:aws:iam::343218219153:role/demo-github-actions`

### Option B: Access Keys (Alternative)

If you can't use OIDC, add these secrets:
- **Name**: `AWS_ACCESS_KEY_ID`
- **Value**: `<your-access-key-id>`

- **Name**: `AWS_SECRET_ACCESS_KEY`
- **Value**: `<your-secret-access-key>`

⚠️ **Note**: Access keys are less secure. Prefer OIDC (Option A) if possible.

## Step 3: Verify Configuration

After setting up variables and secrets:

1. **Push a commit to main branch**:
   ```bash
   git commit --allow-empty -m "test: trigger GitHub Actions"
   git push origin main
   ```

2. **Check GitHub Actions**:
   - Go to: https://github.com/lmnagaraju209/eks-setup-endtoend/actions
   - Watch the workflow run
   - Verify it completes successfully

3. **Verify ECR images**:
   ```bash
   aws ecr describe-images \
     --repository-name taskmanager-backend \
     --region <your-region>
   
   aws ecr describe-images \
     --repository-name taskmanager-frontend \
     --region <your-region>
   ```

## Expected Workflow Behavior

When you push to `main` branch:

1. ✅ **Tests run** (backend and frontend)
2. ✅ **Images built** (backend and frontend)
3. ✅ **Trivy scans** images for vulnerabilities
4. ✅ **Images pushed to ECR**:
   - `343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-backend:<commit-sha>`
   - `343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-frontend:<commit-sha>`
   - Also tagged as `latest`
5. ✅ **Helm values updated** (`helm/eks-setup-app/values.yaml`)
6. ✅ **Changes committed back to Git**

## Troubleshooting

### Workflow fails with "Invalid account ID"

- Verify `AWS_ACCOUNT_ID` variable is set to `343218219153`
- Check for typos or extra spaces

### Workflow fails with "UnauthorizedOperation"

- Check OIDC role or access keys are configured correctly
- Verify IAM permissions in AWS account `343218219153`

### Workflow fails with "RepositoryNotFoundException"

- Ensure ECR repositories exist:
  ```bash
  aws ecr describe-repositories --region <region>
  ```
- They should be created by Terraform if `terraform apply` completed successfully

### Images not appearing in ECR

- Check workflow logs for errors
- Verify AWS credentials have ECR push permissions
- Ensure region matches your `AWS_REGION` variable

## ECR Repository Names

These are hardcoded (no need to configure):
- Backend: `taskmanager-backend`
- Frontend: `taskmanager-frontend`

Full URLs will be:
- `343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-backend`
- `343218219153.dkr.ecr.<region>.amazonaws.com/taskmanager-frontend`

## Summary Checklist

- [ ] `AWS_ACCOUNT_ID = 343218219153` set in GitHub Variables
- [ ] `AWS_REGION` set in GitHub Variables
- [ ] `AWS_ROLE_TO_ASSUME` (OIDC) OR `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` set in GitHub Secrets
- [ ] Terraform applied (infrastructure created)
- [ ] ECR repositories exist (`taskmanager-backend`, `taskmanager-frontend`)
- [ ] Push to main branch to test workflow

## Next Steps

Once GitHub Actions is working:

1. ✅ Configure ArgoCD to monitor Git repository
2. ✅ ArgoCD will automatically deploy when Helm values change
3. ✅ Complete GitOps workflow: Code → Build → Deploy → EKS

See `PHASE4_PHASE5_WORKFLOW.md` for the complete workflow documentation.

