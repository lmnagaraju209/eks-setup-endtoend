# ArgoCD Setup Instructions (Public Repository Safe)

This guide shows how to set up ArgoCD with your GitHub repository **without exposing sensitive tokens**.

## Prerequisites

- GitHub Personal Access Token with `repo` scope
- ArgoCD installed in your cluster (via Terraform)
- Access to your EKS cluster

## Your Repository

- **GitHub Repository**: `https://github.com/lmnagaraju209/eks-setup-endtoend.git`
- **GitHub Username**: `lmnagaraju209`

## Step 1: Get Your GitHub Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Create a new token or use an existing one
3. Ensure it has `repo` scope (full control of private repositories)
4. **Save the token securely** - you'll need it in Step 2

## Step 2: Configure ArgoCD Repository Access

### Option A: Using ArgoCD UI (Recommended)

```bash
# 1. Port-forward ArgoCD
kubectl -n argocd port-forward svc/argocd-server 8080:80

# 2. Get admin password
cd terraform
terraform output -raw argocd_admin_password
```

Then:
1. Open browser: http://localhost:8080
2. Login: Username `admin`, Password `<from-terraform-output>`
3. Go to **Settings** → **Repositories** → **Connect Repo**
4. Fill in:
   - **Type**: `git`
   - **Project Name**: `default`
   - **Repository URL**: `https://github.com/lmnagaraju209/eks-setup-endtoend.git`
   - **Connection method**: `via HTTPS (using username and password)`
   - **Username**: `lmnagaraju209`
   - **Password**: `<your-github-token>` (paste your token here)
5. Click **Connect**
6. Verify it shows as "Successful"

### Option B: Using ArgoCD CLI

```bash
# Login to ArgoCD
cd terraform
ARGOCD_PASSWORD=$(terraform output -raw argocd_admin_password)
kubectl -n argocd port-forward svc/argocd-server 8080:80 &
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD

# Add repository (replace <your-token> with your actual token)
argocd repo add https://github.com/lmnagaraju209/eks-setup-endtoend.git \
  --username lmnagaraju209 \
  --password <your-token> \
  --type git

# Verify
argocd repo list
```

### Option C: Using Kubernetes Secret (Most Secure)

```bash
# Create secret (replace <your-token> with your actual token)
kubectl create secret generic github-repo-argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/lmnagaraju209/eks-setup-endtoend.git \
  --from-literal=username=lmnagaraju209 \
  --from-literal=password='<your-token>' \
  -n argocd

# Label it for ArgoCD to recognize
kubectl label secret github-repo-argocd argocd.argoproj.io/secret-type=repository -n argocd

# Verify
kubectl get secret github-repo-argocd -n argocd
```

## Step 3: Create ArgoCD Application

### Option A: Using kubectl

```bash
# Apply the manifest (already configured with your repo URL)
kubectl apply -f argocd-application.yaml

# Verify
kubectl get applications -n argocd
kubectl describe application taskmanager -n argocd
```

### Option B: Using Terraform

Edit `terraform/terraform.tfvars`:

```hcl
argocd_application_enabled = true
argocd_git_repo_url        = "https://github.com/lmnagaraju209/eks-setup-endtoend.git"
argocd_application_target_revision = "main"
argocd_application_namespace        = "default"
argocd_application_sync_policy      = "automated"
```

Then:
```bash
cd terraform
terraform apply
```

## Step 4: Verify Setup

```bash
# Check application status
kubectl get applications -n argocd
kubectl get application taskmanager -n argocd -o yaml

# Check if ArgoCD can access the repository
argocd repo get https://github.com/lmnagaraju209/eks-setup-endtoend.git
```

## Complete Workflow Test

1. Make a code change and push to main
2. Watch GitHub Actions update Helm values
3. ArgoCD will detect the change (within 3 minutes) and deploy
4. Verify deployment in your cluster

## Troubleshooting

See `argocd-application-setup.md` for detailed troubleshooting steps.

## Security Notes

- ✅ **Never commit tokens to Git**
- ✅ **Use Kubernetes secrets** for storing tokens
- ✅ **Rotate tokens regularly**
- ✅ **Use minimal permissions** (only `repo` scope needed)

