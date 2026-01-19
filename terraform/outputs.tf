# ============================================================================
# Output Values
# ============================================================================
#
# These are values that Terraform prints after running apply.
# Useful for:
# - Getting cluster endpoint to configure kubectl
# - Finding resource IDs for other tools
# - Sharing information with team members
#
# You can access these with: terraform output <name>
# Or: terraform output -json (for all outputs as JSON)

# Cluster name - useful for kubectl commands
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

# Cluster endpoint - this is what kubectl connects to
# You'll see this in the output after terraform apply
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

# Security group ID attached to the cluster
# Useful if you need to modify firewall rules
output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

# Certificate authority data - needed for kubectl to verify the cluster
# This is automatically handled when you run aws eks update-kubeconfig
output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

# OIDC issuer URL - needed for IRSA (IAM Roles for Service Accounts)
# If you're creating IAM roles for pods, you'll need this
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

# VPC ID (existing or newly created)
# Useful for creating other resources in the same VPC
output "vpc_id" {
  description = "ID of the VPC (existing or newly created)"
  value       = local.vpc_id
}

# VPC CIDR block
# Useful for security group rules (allow traffic from VPC CIDR)
output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value = local.should_use_existing ? (
    local.selected_vpc_id != "" ? data.aws_vpc.existing[0].cidr_block : "N/A"
  ) : module.vpc[0].vpc_cidr_block
}

# Whether VPC was auto-detected due to limit being reached
# Useful for debugging - tells you if we reused an existing VPC
output "vpc_auto_detected" {
  description = "Whether VPC was auto-detected due to limit being reached"
  value       = local.vpc_limit_reached && !var.use_existing_vpc
}

# Number of VPCs in the region
# Useful for understanding if you're close to the limit
output "vpc_count" {
  description = "Number of VPCs in the region"
  value       = local.vpc_count
}

# Private subnet IDs
# These are where your pods run
# Useful for creating other resources in the same subnets
output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = local.private_subnet_ids
}

# Public subnet IDs
# These are where load balancers run
# Useful for creating other resources in the same subnets
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = local.public_subnet_ids
}

# Security group ID attached to node groups
# Useful if you need to modify firewall rules for nodes
output "node_security_group_id" {
  description = "Security group ID attached to the EKS node groups"
  value       = module.eks.node_security_group_id
}

# Command to configure kubectl
# Copy and paste this command to set up kubectl access
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Command to check node group status
# Useful for debugging if nodes aren't coming up
output "node_group_status" {
  description = "Check node group status with: aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name main --region <region>"
  value       = "Run: aws eks describe-nodegroup --cluster-name ${module.eks.cluster_name} --nodegroup-name main --region ${var.aws_region}"
}

# S3 bucket name for Terraform state (sanitized)
# Useful for checking state or setting up backups
output "terraform_state_bucket_name" {
  description = "S3 bucket name for Terraform state (sanitized - underscores converted to hyphens)"
  value       = local.sanitized_bucket_name
}

# DynamoDB table name for state locking
# Useful for checking locks or troubleshooting
output "terraform_state_dynamodb_table" {
  description = "DynamoDB table name for state locking (includes account ID if include_account_id_in_bucket_name=true)"
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "aws_account_id" {
  description = "Current AWS account ID (used in bucket and table naming)"
  value       = data.aws_caller_identity.current.account_id
}

# Command to set up remote state backend
# Run this after first apply to migrate state to S3
output "setup_backend_command" {
  description = "After first apply, run this to set up remote state backend"
  value       = "cp backend.tf.example backend.tf && terraform init -migrate-state"
}

# Phase 4 outputs (CI/CD)
# Note: aws_account_id output is defined above (line 129)

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "ecr_backend_repository_url" {
  description = "ECR repository URL for backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "ECR repository URL for frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_backend_repository_name" {
  description = "ECR repository name for backend image"
  value       = aws_ecr_repository.backend.name
}

output "ecr_frontend_repository_name" {
  description = "ECR repository name for frontend image"
  value       = aws_ecr_repository.frontend.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions (OIDC) to assume"
  value       = aws_iam_role.github_actions.arn
}

# Phase 5 outputs (ArgoCD)
output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = var.argocd_namespace
}

output "argocd_server_port_forward" {
  description = "Port-forward command for ArgoCD UI (local access)"
  value       = "kubectl -n ${var.argocd_namespace} port-forward svc/argocd-server 8080:80"
}

output "argocd_admin_password" {
  description = "Initial ArgoCD admin password (if enable_argocd=true). Username is 'admin'."
  value       = var.enable_argocd ? try(base64decode(data.kubernetes_secret.argocd_initial_admin[0].data["password"]), "Password not available yet. Run: kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d") : null
  sensitive   = true
}

output "argocd_url" {
  description = "ArgoCD URL if ingress is enabled and host is set"
  value       = (var.enable_argocd && var.argocd_ingress_enabled && var.argocd_ingress_host != "") ? "https://${var.argocd_ingress_host}" : null
}

output "application_url" {
  description = "Application URL (requires enable_public_domain_ingress=true). Uses HTTPS with self-signed cert when use_acm_certificate=false."
  value       = var.enable_public_domain_ingress ? "https://${var.application_host}" : null
}

output "argocd_subpath_url" {
  description = "ArgoCD URL on the shared domain (requires enable_public_domain_ingress=true). Uses HTTPS with self-signed cert when use_acm_certificate=false."
  value       = (var.enable_public_domain_ingress && var.enable_argocd) ? "https://${var.application_host}/argocd" : null
}

output "monitoring_subpath_url" {
  description = "Grafana URL on the shared domain (requires enable_public_domain_ingress=true). Uses HTTPS with self-signed cert when use_acm_certificate=false."
  value       = (var.enable_public_domain_ingress && var.enable_monitoring) ? "https://${var.application_host}/monitoring" : null
}

# Phase 7 outputs (Monitoring)
output "monitoring_namespace" {
  description = "Namespace where monitoring stack is installed"
  value       = var.monitoring_namespace
}

output "grafana_admin_user" {
  description = "Grafana admin username"
  value       = "admin"
}

output "grafana_admin_password" {
  description = "Grafana admin password (if enable_monitoring=true)."
  value       = var.enable_monitoring ? local.grafana_admin_password_effective : null
  sensitive   = true
}

output "grafana_port_forward" {
  description = "Port-forward command for Grafana (local access)"
  value       = "kubectl -n ${var.monitoring_namespace} port-forward svc/kube-prometheus-stack-grafana 3000:80"
}

output "grafana_url" {
  description = "Grafana URL if ingress is enabled and host is set"
  value       = (var.enable_monitoring && var.grafana_ingress_enabled && var.grafana_ingress_host != "") ? "https://${var.grafana_ingress_host}" : null
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name for container logs (if enable_logging=true)."
  value       = var.enable_logging ? local.cloudwatch_log_group_name_effective : null
}

output "alertmanager_slack_enabled" {
  description = "Whether Alertmanager Slack notifications are configured"
  value       = nonsensitive(var.alertmanager_slack_webhook_url) != ""
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets Operator (IRSA)"
  value       = var.enable_external_secrets ? aws_iam_role.external_secrets[0].arn : null
}