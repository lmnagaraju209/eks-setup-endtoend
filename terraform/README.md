# EKS Infrastructure

Terraform configuration for AWS EKS cluster setup.

## Setup

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Copy `terraform.tfvars.example` to `terraform.tfvars` and update values.

## What Gets Created

- VPC with public/private subnets
- EKS cluster
- Node groups (EC2 instances)
- IAM roles for service accounts
- ECR repositories for app images (backend/frontend)
- GitHub Actions OIDC IAM role (Phase 4) for pushing images to ECR
- EKS add-ons (VPC CNI, CoreDNS, kube-proxy, EBS CSI)

## AWS Console Access

Add your IAM user ARN to `terraform.tfvars`:

```bash
aws sts get-caller-identity --query 'Arn' --output text
```

Then set `admin_iam_user_arn` in `terraform.tfvars` and run `terraform apply`.

## Connect to Cluster

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
kubectl get nodes
```

## Phase 4 (CI/CD) outputs

After `terraform apply`, grab the values needed for GitHub Actions:

```bash
terraform output aws_account_id
terraform output aws_region
terraform output github_actions_role_arn
terraform output ecr_backend_repository_url
terraform output ecr_frontend_repository_url
```

## Phase 5 (ArgoCD) install via Terraform

ArgoCD is installed during `terraform apply` by default (`enable_argocd = true`).

After apply:

- Get ArgoCD admin password:

```bash
cd terraform
terraform output -raw argocd_admin_password
```

- Access ArgoCD UI via port-forward:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
```

Then open `http://localhost:8080` and login as `admin`.

## Phase 7 (Monitoring) install via Terraform

Monitoring is installed during `terraform apply` by default (`enable_monitoring = true`).

After apply:

- Get Grafana admin password:

```bash
cd terraform
terraform output -raw grafana_admin_password
```

- Access Grafana via port-forward:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Then open `http://localhost:3000` and login as `admin`.

## Phase 7 (Logging) install via Terraform

Logging is installed during `terraform apply` by default (`enable_logging = true`).

After apply, container logs should appear in CloudWatch Logs under:

```bash
cd terraform
terraform output -raw cloudwatch_log_group_name
```

## Phase 8 (Security) highlights

This repo implements Phase 8 items via Terraform + Helm:

- **EKS audit logs**: enabled by default (`enable_eks_control_plane_audit_logs = true`)
- **External Secrets Operator (ESO)**: installed by default (`enable_external_secrets = true`) with IRSA to AWS Secrets Manager
- **Container scanning**: Trivy scans run in GitHub Actions before pushing images
- **Pod hardening + NetworkPolicy**: applied via the Helm chart (`helm/eks-setup-app`)

## Cost

Approximately $155-175/month:
- EKS: $73/month
- Nodes: ~$30/month (2x t3.small)
- NAT Gateway: ~$32/month
- Other: ~$20/month
