# Phase 4 & Phase 5: Complete CI/CD + GitOps Workflow

This document describes the complete workflow where code changes trigger automatic builds, image pushes, and deployments via GitHub Actions and ArgoCD.

---

## 🔄 Complete Workflow Overview

```
Developer pushes code to main
    ↓
GitHub Actions runs (.github/workflows/deploy.yml)
    ├─ Builds & tests code
    ├─ Builds Docker images
    ├─ Pushes images to ECR (taskmanager-backend, taskmanager-frontend)
    ├─ Updates helm/eks-setup-app/values.yaml with new image tags
    └─ Commits & pushes changes back to Git
    ↓
ArgoCD detects Git repository changes
    ├─ Polls Git repo (every 3 minutes) or receives webhook
    ├─ Detects updated values.yaml
    └─ Automatically syncs and deploys to EKS
    ↓
Application deployed to EKS
    ├─ New pods created with updated images
    ├─ Old pods terminated (rolling update)
    └─ Health checks verify deployment success
```

---

## ✅ Phase 4: CI/CD (GitHub Actions) - Status: COMPLETE

### What's Implemented

1. **Workflow File**: `.github/workflows/deploy.yml`
   - Triggers on: push to `main` branch, PR to `main`
   - On PR: Runs tests only
   - On push to main: Builds, pushes images, updates Helm values

2. **Docker Image Build & Push**:
   - Backend: `taskmanager-backend`
   - Frontend: `taskmanager-frontend`
   - Tags: `${GITHUB_SHA}` (commit SHA) and `latest`
   - Pushed to ECR: `${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com`

3. **Helm Values Update**:
   - Updates `helm/eks-setup-app/values.yaml`:
     - `backend.image.repository = <account>.dkr.ecr.<region>.amazonaws.com/taskmanager-backend`
     - `backend.image.tag = <commit-sha>`
     - `frontend.image.repository = <account>.dkr.ecr.<region>.amazonaws.com/taskmanager-frontend`
     - `frontend.image.tag = <commit-sha>`
   - Commits and pushes changes back to Git

4. **Security**:
   - Trivy image scanning (fails on CRITICAL/HIGH vulnerabilities)
   - OIDC authentication (no long-lived credentials)

### GitHub Configuration Required

**Variables** (Repo Settings → Secrets and variables → Actions → Variables):
- `AWS_ACCOUNT_ID`: Your AWS account ID
- `AWS_REGION`: Your AWS region (e.g., `us-east-1`)

**Secrets** (Repo Settings → Secrets and variables → Actions → Secrets):
- `AWS_ROLE_TO_ASSUME`: IAM role ARN (from `terraform output github_actions_role_arn`)

**OR** (if not using OIDC):
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key

See `CI_CD_GUIDE.md` for detailed setup instructions.

---

## ⚠️ Phase 5: ArgoCD - Status: PARTIALLY COMPLETE

### What's Implemented

1. **ArgoCD Installation**: ✅
   - Installed via Terraform (`terraform/argocd.tf`)
   - Namespace: `argocd`
   - Chart: `argo-cd` (version 7.8.2)

2. **ArgoCD Application**: ❌ **MISSING**
   - ArgoCD is installed, but no Application CRD exists to monitor Git and deploy

### What's Missing

The ArgoCD Application resource that:
- Monitors your Git repository
- Watches for changes to `helm/eks-setup-app/values.yaml`
- Automatically syncs and deploys to EKS when changes are detected

---

## 🚀 Setup ArgoCD Application (Complete Phase 5)

You have **two options** to create the ArgoCD Application:

### Option 1: Using Terraform (Infrastructure as Code) - Recommended

Edit `terraform/terraform.tfvars`:

```hcl
# Enable ArgoCD Application
argocd_application_enabled = true
argocd_git_repo_url        = "https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.git"
argocd_application_target_revision = "main"
argocd_application_namespace        = "default"
argocd_application_sync_policy      = "automated"  # Auto-sync on Git changes
```

Then apply:

```bash
cd terraform
terraform plan
terraform apply
```

This creates the ArgoCD Application automatically.

### Option 2: Using kubectl/ArgoCD CLI (Manual)

1. **Update `argocd-application.yaml`** with your repository URL:
   ```yaml
   source:
     repoURL: https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.git
   ```

2. **Apply the manifest**:
   ```bash
   kubectl apply -f argocd-application.yaml
   ```

See `argocd-application-setup.md` for detailed instructions.

---

## 🔐 Configure Git Repository Access

ArgoCD needs access to your Git repository. Configure it in ArgoCD UI:

1. **Port-forward ArgoCD**:
   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:80
   ```

2. **Get admin password**:
   ```bash
   cd terraform
   terraform output -raw argocd_admin_password
   ```

3. **Login to ArgoCD UI**: http://localhost:8080
   - Username: `admin`
   - Password: (from step 2)

4. **Add Repository** (Settings → Repositories → Connect Repo):
   - **Public repo**: Just enter URL, no auth needed
   - **Private repo**: Use GitHub Personal Access Token or SSH key
     - Token permissions: `repo` (full control of private repositories)
     - Username: Your GitHub username
     - Password: Personal access token

---

## ✅ Verify Complete Workflow

### 1. Check GitHub Actions

After pushing code to `main`:
- Go to GitHub → Actions tab
- Workflow should run and complete successfully
- Verify `helm/eks-setup-app/values.yaml` is updated with new image tags

### 2. Check ArgoCD Application

```bash
# Get application status
kubectl get applications -n argocd
kubectl describe application taskmanager -n argocd

# Check sync status via ArgoCD CLI
argocd app get taskmanager
```

Expected:
- **Sync Status**: `Synced` ✅
- **Health Status**: `Healthy` ✅

### 3. Check Deployed Pods

```bash
# Verify new image tags are deployed
kubectl get pods -n default -l app=backend -o jsonpath='{.items[0].spec.containers[0].image}'
kubectl get pods -n default -l app=frontend -o jsonpath='{.items[0].spec.containers[0].image}'
```

The image tags should match the commit SHA from GitHub Actions.

---

## 🧪 Test the Complete Workflow

1. **Make a code change**:
   ```bash
   # Edit any file in services/backend or services/frontend
   echo "// test change" >> services/backend/src/main/java/com/example/backend/BackendApplication.java
   ```

2. **Commit and push**:
   ```bash
   git add .
   git commit -m "test: trigger CI/CD pipeline"
   git push origin main
   ```

3. **Watch GitHub Actions**:
   - Monitor the workflow run
   - Wait for it to complete
   - Verify Helm values are updated

4. **Watch ArgoCD**:
   ```bash
   # ArgoCD polls every 3 minutes by default
   # Or refresh manually:
   argocd app get taskmanager --refresh
   
   # Watch sync in real-time:
   watch -n 2 'kubectl get application taskmanager -n argocd -o jsonpath="{.status.sync.status}"'
   ```

5. **Verify deployment**:
   ```bash
   # Check pods are rolling out
   kubectl get pods -n default -w
   
   # Verify new image is deployed
   kubectl get deployment backend -n default -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

---

## 🔧 Troubleshooting

### GitHub Actions fails to push images

**Check IAM permissions**:
```bash
# Verify GitHub Actions role has ECR permissions
aws iam get-role-policy --role-name <project>-github-actions --policy-name <policy-name>
```

**Check OIDC setup**:
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers
```

### ArgoCD Application shows "Unknown" status

**Check repository access**:
```bash
# Test if ArgoCD can access the repo
argocd repo get https://github.com/YOUR_ORG/YOUR_REPO.git
```

**Check application logs**:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

### ArgoCD not detecting Git changes

**Option 1: Enable webhook** (faster than polling):
1. Get ArgoCD webhook URL from Ingress or service
2. Add webhook in GitHub: Settings → Webhooks → Add webhook
3. Payload URL: `https://<argocd-ingress>/api/webhook`
4. Content type: `application/json`
5. Events: `Just the push event`

**Option 2: Reduce polling interval** (in ArgoCD Application):
- Default is 3 minutes
- Can be configured in ArgoCD settings

---

## 📊 Workflow Summary

| Step | Component | Status | Action Required |
|------|-----------|--------|-----------------|
| 1. Code push | Git | ✅ | None |
| 2. Build & test | GitHub Actions | ✅ | None |
| 3. Build images | GitHub Actions | ✅ | None |
| 4. Push to ECR | GitHub Actions | ✅ | None |
| 5. Update Helm values | GitHub Actions | ✅ | None |
| 6. Commit to Git | GitHub Actions | ✅ | None |
| 7. Detect Git changes | ArgoCD | ⚠️ | Create Application |
| 8. Sync to EKS | ArgoCD | ⚠️ | Create Application |
| 9. Deploy pods | Kubernetes | ✅ | Automatic after sync |

---

## 🎯 Next Steps

1. ✅ **Phase 4 is complete** - GitHub Actions workflow is working
2. ⚠️ **Complete Phase 5** - Create ArgoCD Application (choose Option 1 or 2 above)
3. ✅ **Configure Git repo access** in ArgoCD UI
4. ✅ **Test the workflow** by pushing code to main
5. ✅ **Monitor deployments** via ArgoCD UI

Once the ArgoCD Application is created, the complete GitOps workflow will be fully automated! 🚀

