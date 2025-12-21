# ArgoCD Application Setup Guide

This guide shows you how to configure ArgoCD to automatically deploy your TaskManager application when Helm values change.

## Complete CI/CD + GitOps Workflow

The workflow you've requested works as follows:

1. **Developer pushes code to main branch**
2. **GitHub Actions runs**:
   - Builds and tests code
   - Builds Docker images
   - Pushes images to ECR (`taskmanager-backend`, `taskmanager-frontend`)
   - Updates `helm/eks-setup-app/values.yaml` with new image tags
   - Commits and pushes changes back to Git
3. **ArgoCD detects Git changes**:
   - Monitors the Git repository (polling or via webhook)
   - Detects changes to `helm/eks-setup-app/values.yaml`
   - Automatically syncs and deploys to EKS cluster
4. **Application deployed to EKS**:
   - New pods are created with updated images
   - Old pods are terminated (rolling update)
   - Health checks verify deployment success

---

## Current Status

### ✅ Phase 4 (CI/CD) - COMPLETE

- ✅ GitHub Actions workflow (`.github/workflows/deploy.yml`)
- ✅ Builds and pushes to ECR on push to main
- ✅ Updates Helm values.yaml with new image tags
- ✅ Commits changes back to Git

### ⚠️ Phase 5 (ArgoCD) - PARTIALLY COMPLETE

- ✅ ArgoCD installed via Terraform
- ❌ **Missing: ArgoCD Application CRD** (to monitor Git and deploy)

---

## Step 1: Get Repository Information

You'll need your GitHub repository details. Check your Terraform variables:

```bash
cd terraform
# Check if github_org and github_repo are set
grep -E "github_org|github_repo" terraform.tfvars
```

Or set them if not already:
```hcl
github_org  = "your-github-username-or-org"
github_repo = "eks-setup-endtoend"  # Your repository name
```

---

## Step 2: Update ArgoCD Application Manifest

Edit `argocd-application.yaml` and update the repository URL:

```yaml
source:
  repoURL: https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.git
  targetRevision: main
  path: helm/eks-setup-app
```

Replace:
- `YOUR_GITHUB_ORG` with your GitHub username or organization
- `YOUR_REPO_NAME` with your repository name (e.g., `eks-setup-endtoend`)

---

## Step 3: Get ArgoCD Admin Password

After Terraform apply, get the ArgoCD admin password:

```bash
cd terraform
terraform output -raw argocd_admin_password
```

Save this password securely.

---

## Step 4: Apply ArgoCD Application

### Option A: Using kubectl (Recommended)

```bash
# Make sure you're connected to your EKS cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Apply the ArgoCD Application
kubectl apply -f argocd-application.yaml

# Verify it was created
kubectl get applications -n argocd

# Check application status
kubectl describe application taskmanager -n argocd
```

### Option B: Using ArgoCD CLI

```bash
# Install ArgoCD CLI (if not installed)
# Windows: choco install argocd
# Mac: brew install argocd
# Linux: See https://argo-cd.readthedocs.io/en/stable/cli_installation/

# Port-forward ArgoCD server
kubectl -n argocd port-forward svc/argocd-server 8080:80

# Login (in another terminal)
argocd login localhost:8080 --username admin --password <password-from-step-3>

# Create application
argocd app create taskmanager \
  --repo https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.git \
  --path helm/eks-setup-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

### Option C: Using ArgoCD UI

1. **Port-forward ArgoCD**:
   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:80
   ```

2. **Open browser**: http://localhost:8080

3. **Login**:
   - Username: `admin`
   - Password: (from Step 3)

4. **Create Application**:
   - Click "New App"
   - Application Name: `taskmanager`
   - Project: `default`
   - Repository URL: `https://github.com/YOUR_GITHUB_ORG/YOUR_REPO_NAME.git`
   - Revision: `main`
   - Path: `helm/eks-setup-app`
   - Destination:
     - Cluster: `https://kubernetes.default.svc`
     - Namespace: `default`
   - Sync Policy:
     - ✅ Automatic sync
     - ✅ Auto-create namespace
     - ✅ Self-heal
     - ✅ Prune resources

---

## Step 5: Configure Git Repository Access

ArgoCD needs access to your Git repository. Configure it in ArgoCD UI:

1. **Go to Settings → Repositories**
2. **Click "Connect Repo"**
3. **Choose connection method**:

### Option A: Public Repository (No Auth Needed)
- Repository URL: `https://github.com/YOUR_ORG/YOUR_REPO.git`
- Connection: `via HTTPS (no auth)`

### Option B: Private Repository (Recommended)

**Using GitHub Personal Access Token**:
1. Create token in GitHub: Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Permissions needed: `repo` (full control of private repositories)
3. In ArgoCD:
   - Type: `git`
   - Repository URL: `https://github.com/YOUR_ORG/YOUR_REPO.git`
   - Connection: `via HTTPS (using username and password)`
   - Username: `YOUR_GITHUB_USERNAME`
   - Password: `<personal-access-token>`

**Using SSH**:
1. Generate SSH key: `ssh-keygen -t ed25519 -C "argocd"`
2. Add public key to GitHub: Settings → SSH and GPG keys
3. Create Secret in Kubernetes:
   ```bash
   kubectl create secret generic github-ssh-key \
     --from-file=sshPrivateKey=~/.ssh/id_ed25519 \
     -n argocd
   ```
4. In ArgoCD:
   - Repository URL: `git@github.com:YOUR_ORG/YOUR_REPO.git`
   - Connection: `via SSH (using SSH key)`

---

## Step 6: Verify Setup

### Check Application Status

```bash
# Via kubectl
kubectl get applications -n argocd
kubectl describe application taskmanager -n argocd

# Via ArgoCD CLI
argocd app get taskmanager

# Via ArgoCD UI
# Open http://localhost:8080 and check the taskmanager application
```

### Expected Status

- **Sync Status**: `Synced` (green)
- **Health Status**: `Healthy` (green)
- **Resources**: All resources created (Deployments, Services, etc.)

---

## Step 7: Test the Complete Workflow

1. **Make a code change** (e.g., update a file in `services/backend`)

2. **Commit and push to main**:
   ```bash
   git add .
   git commit -m "test: trigger deployment"
   git push origin main
   ```

3. **Watch GitHub Actions**:
   - Go to GitHub → Actions tab
   - Watch the workflow run
   - Verify images are pushed to ECR
   - Verify `helm/eks-setup-app/values.yaml` is updated

4. **Watch ArgoCD sync**:
   ```bash
   # Via CLI
   argocd app get taskmanager --refresh
   
   # Or watch in UI
   # ArgoCD should show "OutOfSync" then automatically sync
   ```

5. **Verify deployment**:
   ```bash
   # Check pods are updated with new image
   kubectl get pods -n default -l app=backend -o jsonpath='{.items[0].spec.containers[0].image}'
   kubectl get pods -n default -l app=frontend -o jsonpath='{.items[0].spec.containers[0].image}'
   ```

---

## Troubleshooting

### ArgoCD Application shows "Unknown" or "Pending"

**Check repository access**:
```bash
# Test if ArgoCD can access the repo
argocd repo get https://github.com/YOUR_ORG/YOUR_REPO.git
```

**Check application logs**:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100
```

### Application sync fails

**Check sync logs**:
```bash
argocd app get taskmanager --refresh
argocd app logs taskmanager --tail=100
```

**Common issues**:
- Repository not accessible (check credentials)
- Helm chart path incorrect
- Image pull errors (check ECR access)
- Resource conflicts

### ArgoCD not detecting Git changes

**Enable webhook** (faster than polling):
1. Get webhook URL from ArgoCD: `kubectl get svc argocd-server -n argocd`
2. Add webhook in GitHub: Settings → Webhooks → Add webhook
3. Payload URL: `https://<argocd-ingress>/api/webhook`
4. Content type: `application/json`
5. Events: `Just the push event`

**Or reduce polling interval** (in ArgoCD Application):
```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    # Poll every 3 minutes (default is 3 minutes)
```

---

## Configuration Reference

### Manual Sync Policy (Production)

For production, you might want manual sync approval:

```yaml
spec:
  syncPolicy:
    # Remove 'automated' section for manual sync
    syncOptions:
      - CreateNamespace=true
```

Then sync manually via:
- UI: Click "Sync" button
- CLI: `argocd app sync taskmanager`
- kubectl: `kubectl patch application taskmanager -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'`

### Sync Windows (Prevent deployments during business hours)

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    # Sync only between 2 AM and 4 AM UTC
    syncWindows:
      - kind: allow
        schedule: '0 2 * * *'
        duration: 2h
        applications:
          - '*'
```

---

## Summary

✅ **Complete Workflow**:

1. Code push → GitHub Actions → Build & Push to ECR → Update Helm values → Commit to Git
2. ArgoCD detects Git change → Syncs → Deploys to EKS → Application updated

**Next Steps**:
1. Update `argocd-application.yaml` with your repository URL
2. Apply the Application: `kubectl apply -f argocd-application.yaml`
3. Configure Git repository access in ArgoCD UI
4. Test by pushing code to main branch
5. Watch ArgoCD automatically deploy! 🚀

