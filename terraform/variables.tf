# ============================================================================
# Input Variables
# ============================================================================
#
# These are the values you provide when running Terraform.
# Some have defaults (good for learning), others you must provide.
#
# I've added explanations for each one - not just what it does, but why
# you might want to change it and what happens if you do.

# AWS region where everything gets created
# Pick one close to you for lower latency, or one that's cheaper
# Different regions have different prices - us-east-1 is usually cheapest
variable "aws_region" {
  description = "AWS region to create everything in (e.g., us-east-1, us-west-2). Pick one close to you for lower latency."
  type        = string
  # No default - Terraform will prompt you
}

# Project name - used in resource names
# Keep it short, lowercase, no spaces
# This becomes part of names like "demo-vpc", "demo" cluster, etc.
variable "project_name" {
  description = "Name for your project. This gets used in resource names (e.g., 'demo' becomes 'demo-vpc', 'demo' cluster). Keep it short and lowercase."
  type        = string
  # No default - Terraform will prompt you
}

# Whether to use an existing VPC
# Set to true if you want to use a specific VPC you already have
# Set to false and we'll auto-detect if you hit the limit and reuse one
variable "use_existing_vpc" {
  description = "Set to true if you want to use a specific existing VPC. If false, we'll auto-detect if you hit the VPC limit (5 per region) and use an existing one automatically."
  type        = bool
  default     = false
}

# VPC ID to use (if use_existing_vpc is true)
# Leave empty and we'll pick the first available if you hit the limit
variable "existing_vpc_id" {
  description = "VPC ID to use if use_existing_vpc is true. If empty and we auto-detect you hit the limit, we'll pick the first available VPC."
  type        = string
  default     = ""
}

# Private subnet IDs for EKS nodes
# These are where your pods run (more secure, no direct internet access)
# If empty and using existing VPC, we'll auto-detect based on MapPublicIpOnLaunch=false
variable "existing_private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes (where your pods run). If empty and using existing VPC, we'll auto-detect based on MapPublicIpOnLaunch=false."
  type        = list(string)
  default     = []
}

# Public subnet IDs for load balancers
# These are where load balancers run (need internet access)
# Optional but recommended - if empty, we'll try to auto-detect
variable "existing_public_subnet_ids" {
  description = "Public subnet IDs for load balancers. If empty and using existing VPC, we'll auto-detect based on MapPublicIpOnLaunch=true. Optional but recommended."
  type        = list(string)
  default     = []
}

# CIDR block for new VPC (only used if creating new VPC)
# 10.0.0.0/16 gives you 65,536 IP addresses - plenty for most use cases
# Make sure it doesn't overlap with any networks you need to connect to
variable "vpc_cidr" {
  description = "CIDR block for VPC (only used if creating new VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

# Availability zones to use
# 2 AZs = cheaper (fewer NAT Gateways, fewer nodes)
# 3 AZs = more reliable (better redundancy)
# For learning, 2 is fine. For production, use 3.
variable "availability_zones" {
  description = "List of availability zones (2 AZs for cost savings, 3 for production). Only used if creating new VPC. Defaults to us-east-2 zones."
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

# Kubernetes version for the EKS cluster
# AWS supports 4 versions at a time - older ones get deprecated
# 1.34 is the latest as of now, but check AWS docs for current supported versions
# Don't use the absolute latest unless you need new features - let it stabilize first
variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster. 1.34 is the latest as of now. AWS supports 4 versions at a time, so older ones get deprecated."
  type        = string
  default     = "1.34"
}

# EC2 instance types for your nodes
# You can list multiple types - AWS will pick based on availability
# t3.small: 2 vCPU, 2GB RAM - fine for learning (~$15/month per node)
# t3.medium: 2 vCPU, 4GB RAM - better for production (~$30/month per node)
# For production, I'd recommend t3.medium or larger
variable "node_group_instance_types" {
  description = "EC2 instance types for your nodes. t3.small is fine for learning (~$15/month per node). For production, use t3.medium or larger. You can list multiple types and AWS will pick based on availability."
  type        = list(string)
  default     = ["t3.small"]
}

# How many nodes you want per availability zone
# 1 per AZ = 2 total nodes (if using 2 AZs)
# More nodes = more redundancy but higher cost
# Start with 1, increase if you need more capacity
variable "node_group_desired_size" {
  description = "How many nodes you want per availability zone. 1 per AZ = 2 total nodes (if using 2 AZs). More nodes = more redundancy but higher cost."
  type        = number
  default     = 1
}

# Minimum nodes per AZ
# Cluster won't scale below this
# Keep at 1 for cost savings, or 2+ for production redundancy
variable "node_group_min_size" {
  description = "Minimum nodes per AZ. Cluster won't scale below this. Keep at 1 for cost savings, or 2+ for production redundancy."
  type        = number
  default     = 1
}

# Maximum nodes per AZ
# Cluster won't scale above this
# Set based on your expected load and budget
variable "node_group_max_size" {
  description = "Maximum nodes per AZ. Cluster won't scale above this. Set based on your expected load and budget."
  type        = number
  default     = 2
}

# Enable NAT Gateway
# Needed so pods in private subnets can reach the internet
# Required for: pulling Docker images, downloading packages, API calls
# Costs ~$32/month per NAT Gateway
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway so pods in private subnets can reach the internet (needed for pulling Docker images, etc.). Costs ~$32/month per NAT Gateway."
  type        = bool
  default     = true
}

# Single NAT Gateway vs one per AZ
# Single: cheaper (~$32/month) but single point of failure
# Multiple: more reliable (~$96/month for 3 AZs) but more expensive
# For learning, single is fine. For production, use multiple.
variable "single_nat_gateway" {
  description = "Use one NAT Gateway for all AZs (cheaper, ~$32/month) or one per AZ (more reliable, ~$96/month). Single is fine for learning, multiple for production."
  type        = bool
  default     = true
}

# Common tags for all resources
# Useful for cost tracking and organization
# AWS billing can break down costs by tags
variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "eks-setup"
    ManagedBy = "terraform"
  }
}

# ============================================================================
# Remote State Configuration
# ============================================================================
#
# Terraform needs to store its state somewhere. We use S3 for storage
# and DynamoDB for locking. This lets you share state with team members
# and prevents conflicts when multiple people run Terraform.

# S3 bucket name for Terraform state
# Must be globally unique (someone else can't have the same name)
# Underscores get converted to hyphens automatically
# If include_account_id_in_bucket_name is true, account ID will be appended automatically
variable "terraform_state_bucket_name" {
  description = "S3 bucket name base for Terraform state (e.g., 'demoeks'). If include_account_id_in_bucket_name=true, account ID will be appended automatically (e.g., 'demoeks-123456789012-statefile'). Must be globally unique."
  type        = string
  # No default - Terraform will prompt you
}

# Include AWS account ID in bucket name for multi-account support
# When true: bucket name = "<bucket-name>-<account-id>-statefile"
# When false: bucket name = "<bucket-name>" (original behavior)
variable "include_account_id_in_bucket_name" {
  description = "If true, automatically append AWS account ID to S3 bucket and DynamoDB table names. This makes them unique per AWS account, allowing easy account switching."
  type        = bool
  default     = true
}

# S3 key/path for Terraform state file
# This is like a file path within the bucket
# You can organize multiple projects by using different paths
variable "terraform_state_key" {
  description = "S3 key/path for Terraform state file"
  type        = string
  default     = "eks-setup/terraform.tfstate"
}

# AWS region for S3 state bucket
# Defaults to aws_region if not specified
# You can use a different region if you want (for disaster recovery)
variable "terraform_state_region" {
  description = "AWS region for S3 state bucket (defaults to aws_region if not specified)"
  type        = string
  default     = ""
}

# DynamoDB table name for state locking
# Prevents two people from modifying infrastructure at the same time
variable "terraform_state_dynamodb_table" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-state-lock"
}

# IAM user ARN to add to aws-auth configmap
# This lets the AWS console view nodes (otherwise it shows 0 nodes)
# Get it with: aws sts get-caller-identity --query 'Arn' --output text
# Optional - if you don't provide this, you can still use kubectl
variable "admin_iam_user_arn" {
  description = "IAM user ARN to add to aws-auth configmap (so AWS console can view nodes). Get it with: aws sts get-caller-identity --query 'Arn' --output text"
  type        = string
  default     = ""
}

# GitHub OIDC inputs (Phase 4)
variable "github_org" {
  description = "GitHub organization/user that owns the repo (used for GitHub Actions OIDC trust)."
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name (used for GitHub Actions OIDC trust)."
  type        = string
  default     = ""
}

# ============================================================================
# Phase 8: Security
# ============================================================================

variable "enable_eks_control_plane_audit_logs" {
  description = "Enable EKS control-plane logs (including audit) to CloudWatch. Recommended for production."
  type        = bool
  default     = true
}