# Udemy Course Recording Script (Beginner Friendly)

This script is for students starting from zero. Keep the pace calm and explain
every new word once, then use it confidently after that.

## 1. Course Welcome (2–3 min)

Hey everyone, welcome to **End-to-End Deployment on AWS EKS**.  
If cloud or DevOps feels intimidating, you’re in the right place.

By the end of this course, you’ll:
- run the app locally
- create the AWS infrastructure
- deploy the app to Kubernetes

### On-screen
- Show the repo root.
- Open `README.md`.

## 2. What Are We Building? (3–4 min)

We have a simple app with three pieces:
- **Frontend**: the website you open in the browser  
- **Backend**: the API the website calls  
- **Database**: where the data is stored  

And we use three tools:
- **Docker**: bundles an app so it runs the same everywhere  
- **Terraform**: creates AWS resources automatically  
- **Helm**: installs apps into Kubernetes  

### On-screen
- Show `services/` (frontend + backend).
- Show `terraform/`.
- Show `helm/eks-setup-app`.

## 3. Run It Locally First (6–8 min)

Let’s make sure the app works on our own computer before we go to the cloud.

### On-screen
```bash
cd services
docker-compose up
```

Explain: Docker Compose starts the database, backend, and frontend together.

When it’s ready:
- Backend: `http://localhost:8082`
- Frontend: `http://localhost:3000`

### Demo
Open the frontend, create a task, then run:
```bash
curl http://localhost:3000/api/v1/items
```

## 4. Create AWS Infrastructure with Terraform (8–10 min)

Now we tell AWS to create the infrastructure. Terraform is like a repeatable
setup script for the cloud.

### On-screen
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Explain: `terraform.tfvars` is where you enter your region and project name.

Then run:
```bash
terraform init
terraform apply
```

Terraform creates:
- **EKS** (your Kubernetes cluster)
- **ECR** (a container image registry)

### On-screen
Copy and run:
```bash
terraform output configure_kubectl
```

Verify the cluster:
```bash
kubectl get nodes
```

Explain: `kubectl` is the command line tool for Kubernetes.

## 5. Build and Push Docker Images (6–8 min)

We now build Docker images and upload them so EKS can download and run them.

Get repo URLs:
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

## 6. Deploy to Kubernetes with Helm (5–7 min)

Helm is an installer for Kubernetes apps. It takes your images and deploys
them as running services.

### On-screen
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

Explain: Pods are running containers. Services expose them on the network.

## 7. Test the Deployment (3–4 min)

Find the frontend URL:
```bash
kubectl get svc
```

Open the LoadBalancer URL and create a task.

Optional health check:
```bash
curl http://<load-balancer-url>/health
```

## 8. CI/CD with GitHub Actions (4–6 min)

Now the nice part: once CI/CD is enabled, a Git push can update the app
automatically.

Explain the flow in plain words:
1. You push code to GitHub.
2. GitHub Actions runs tests and builds images.
3. Images are pushed to ECR.
4. The cluster deploys the new images.

Keep it short here. We’ll do a deep dive in the next module.

## 9. GitHub Actions Setup from Scratch (6–8 min)

Let’s set up GitHub Actions from zero so the pipeline can deploy automatically.

### Step 1: Create the IAM role for GitHub Actions (OIDC)

In this project, Terraform creates the IAM role for GitHub Actions.
Make sure you set these in `terraform.tfvars` before `terraform apply`:
- `github_org`
- `github_repo`

After apply, copy the role ARN:
```bash
terraform output github_actions_role_arn
```

### Step 2: Add GitHub variables and secrets

Go to your GitHub repo → Settings → Secrets and variables → Actions.

Add Variables:
- `AWS_ACCOUNT_ID`
- `AWS_REGION`

Add Secret:
- `AWS_ROLE_TO_ASSUME` (paste the role ARN from Terraform output)

### Step 3: Push code to trigger the pipeline

Now push any change to the `main` branch.
GitHub Actions will build, test, push images to ECR, and update Helm values.

### Step 4: Verify deployment

After the workflow finishes:
```bash
kubectl get pods
kubectl get svc
```

Open the LoadBalancer URL and confirm the new version is live.

## 10. Wrap Up (2–3 min)

You now completed a full beginner-friendly deployment:
1. Run locally with Docker
2. Create AWS infrastructure with Terraform
3. Deploy to Kubernetes with Helm
4. Understand the CI/CD flow

Thanks for watching. In the next lesson, we’ll make CI/CD fully automatic with
GitHub Actions.
