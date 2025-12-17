# EKS Cluster Setup - Complete Infrastructure
#
# This file creates everything you need to run Kubernetes on AWS:
# - VPC with networking (or reuses existing if you hit limits)
# - EKS cluster (the Kubernetes control plane)
# - Node groups (EC2 instances that run your pods)
# - Add-ons (essential Kubernetes components)
# - IAM roles for pods to access AWS services
#
# Takes about 15-20 minutes from start to finish. Most of that time
# is waiting for AWS to provision the EKS control plane.
#
# I've added comments throughout explaining not just what each piece does,
# but why it exists and what problems it solves. This should help you
# understand the full picture, not just copy-paste.

# ============================================================================
# AWS Provider Configuration
# ============================================================================
# 
# This tells Terraform which AWS account and region to use. The region
# you pick affects latency (closer = faster) and cost (some regions are
# cheaper than others).
#
# default_tags automatically apply to every resource we create. This is
# super useful for cost tracking and organization. AWS billing can break
# down costs by tags, so you can see exactly what this project costs.

provider "aws" {
  region = var.aws_region

  # These tags get applied to everything - useful for filtering in console
  # and cost allocation reports
  default_tags {
    tags = var.tags
  }
}

# ============================================================================
# Data Sources - Getting Information About Your AWS Account
# ============================================================================
#
# Data sources let you query AWS for information without creating anything.
# We use these to figure out what's already in your account and make smart
# decisions (like reusing VPCs if you've hit the limit).

# Get list of availability zones in the region you chose
# We need this to spread resources across multiple AZs for redundancy
# If one AZ goes down, your cluster keeps running
data "aws_availability_zones" "available" {
  state = "available" # Only show AZs that are actually available
}

# Account and region info are defined in data.tf

# Count how many VPCs you already have in this region
# AWS limits you to 5 VPCs per region by default. If you're learning
# or testing, you'll hit this limit fast. We check this so we can
# automatically reuse an existing VPC instead of failing.
data "aws_vpcs" "all" {
  filter {
    name   = "state"
    values = ["available"] # Only count VPCs that are actually usable
  }
}

# ============================================================================
# Local Values - Helper Variables for Logic
# ============================================================================
#
# Locals are like variables, but they're computed from other values.
# We use them to make decisions and avoid repeating complex expressions.
#
# The VPC logic here is a bit complex because we want to be smart:
# - If you explicitly want to use an existing VPC, use it
# - If you hit the VPC limit (5 per region), automatically reuse one
# - Otherwise, create a brand new VPC
#
# This saves you from having to manually configure things every time
# you hit the limit.

locals {
  # Count how many VPCs exist
  vpc_count = length(data.aws_vpcs.all.ids)

  # AWS default limit is 5 VPCs per region
  # If you're at 5, you can't create more (unless you request a limit increase)
  vpc_limit_reached = local.vpc_count >= 5

  # Decision: should we use an existing VPC?
  # True if you explicitly said so, OR if we hit the limit
  should_use_existing = var.use_existing_vpc || local.vpc_limit_reached

  # Which VPC should we use?
  # Priority order:
  # 1. If you gave us a specific VPC ID, use that
  # 2. If we hit the limit and found VPCs, use the first one
  # 3. Otherwise, we'll create a new one (empty string means "create new")
  selected_vpc_id = local.should_use_existing ? (
    var.existing_vpc_id != "" ? var.existing_vpc_id : (
      local.vpc_limit_reached && length(data.aws_vpcs.all.ids) > 0 ? data.aws_vpcs.all.ids[0] : ""
    )
  ) : ""

  # S3 bucket names can't have underscores, only hyphens
  # If someone types "my_state_bucket", we convert it to "my-state-bucket"
  # This prevents errors later when Terraform tries to create the bucket
  sanitized_bucket_name = lower(replace(var.terraform_state_bucket_name, "_", "-"))
}

# If we're using an existing VPC, fetch its details
# We need this to get the CIDR block and other info
data "aws_vpc" "existing" {
  count = local.should_use_existing && local.selected_vpc_id != "" ? 1 : 0
  id    = local.selected_vpc_id
}

# Auto-detect subnets in the existing VPC
# This makes life easier - you don't have to manually find subnet IDs
# We'll figure out which subnets are public vs private automatically
data "aws_subnets" "auto_all" {
  count = local.should_use_existing && local.selected_vpc_id != "" && (
    length(var.existing_private_subnet_ids) == 0 || length(var.existing_public_subnet_ids) == 0
  ) ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [local.selected_vpc_id]
  }
}

# Get detailed info about each subnet
# We need this to tell which are public (have internet gateway) vs private
data "aws_subnet" "auto_details" {
  for_each = local.should_use_existing && local.selected_vpc_id != "" && length(data.aws_subnets.auto_all) > 0 ? toset(data.aws_subnets.auto_all[0].ids) : toset([])
  id       = each.value
}

# More local values for subnet logic
locals {
  # Private subnets: map_public_ip_on_launch = false
  # These are where your pods run. More secure because they can't be
  # directly accessed from the internet.
  auto_private_subnets = length(data.aws_subnet.auto_details) > 0 ? [
    for subnet_id, subnet in data.aws_subnet.auto_details :
    subnet_id if !subnet.map_public_ip_on_launch
  ] : []

  # Public subnets: map_public_ip_on_launch = true
  # These are where load balancers run. They need internet access
  # so users can reach your applications.
  auto_public_subnets = length(data.aws_subnet.auto_details) > 0 ? [
    for subnet_id, subnet in data.aws_subnet.auto_details :
    subnet_id if subnet.map_public_ip_on_launch
  ] : []

  # Final decision: use provided subnets if given, otherwise use auto-detected
  final_private_subnet_ids = local.should_use_existing ? (
    length(var.existing_private_subnet_ids) > 0 ? var.existing_private_subnet_ids : local.auto_private_subnets
  ) : []

  final_public_subnet_ids = local.should_use_existing ? (
    length(var.existing_public_subnet_ids) > 0 ? var.existing_public_subnet_ids : local.auto_public_subnets
  ) : []

  # Final VPC and subnet IDs to use throughout the rest of the config
  # Either from existing VPC or from the module we'll create
  vpc_id = local.should_use_existing ? (
    local.selected_vpc_id != "" ? data.aws_vpc.existing[0].id : ""
  ) : module.vpc[0].vpc_id

  private_subnet_ids = local.should_use_existing ? local.final_private_subnet_ids : module.vpc[0].private_subnets
  public_subnet_ids  = local.should_use_existing ? local.final_public_subnet_ids : module.vpc[0].public_subnets
}

# ============================================================================
# Terraform State Storage (S3 + DynamoDB)
# ============================================================================
# 
# Terraform needs to remember what it created. This "state" is stored in
# a file. By default, it's local (terraform.tfstate), but that's a problem:
# - Can't share with team members
# - Lost if your laptop dies
# - Can't run from multiple machines
#
# Solution: Store state in S3 (shared, backed up) with DynamoDB locking
# (prevents two people from modifying infrastructure at the same time).
#
# First run: We create the bucket and table, but state is still local
# After first apply: You copy backend.tf.example to backend.tf and migrate
# Future runs: State automatically syncs with S3

# S3 bucket to store Terraform state
# This is like a database of your infrastructure - Terraform reads it
# before making changes to see what already exists
resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.sanitized_bucket_name
  force_destroy = false # Safety: don't let someone accidentally delete state

  tags = merge(var.tags, {
    Name    = "Terraform State Bucket"
    Purpose = "Terraform remote state storage"
  })
}

# Enable versioning on the state bucket
# This lets you recover old state if something goes wrong
# Super useful if you accidentally run terraform destroy
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest
# State files contain sensitive info (resource IDs, sometimes secrets)
# Encryption ensures even if someone gets access to S3, they can't read it
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # AWS-managed encryption, no extra cost
    }
  }
}

# Block public access to state bucket
# State contains sensitive information - never make it public
# This is a safety measure that prevents accidental exposure
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking
# When you run terraform apply, it creates a lock entry here
# If someone else tries to run terraform at the same time, they see the lock
# and either wait or fail (depending on settings)
#
# This prevents two people from modifying infrastructure simultaneously,
# which would cause conflicts and potentially break things
resource "aws_dynamodb_table" "terraform_state_lock" {
  name         = var.terraform_state_dynamodb_table
  billing_mode = "PAY_PER_REQUEST" # Only pay for what you use - perfect for locks
  hash_key     = "LockID"          # The lock ID is the primary key

  attribute {
    name = "LockID"
    type = "S" # String type
  }

  tags = merge(var.tags, {
    Name    = "Terraform State Lock Table"
    Purpose = "Terraform state locking"
  })
}

# ============================================================================
# VPC and Networking
# ============================================================================
# 
# VPC (Virtual Private Cloud) is your isolated network in AWS.
# Think of it like a private datacenter that only you can access.
#
# Subnets divide your VPC into smaller networks:
# - Public subnets: Have direct internet access (via Internet Gateway)
#   Used for: Load balancers, NAT Gateways
#   Why: Load balancers need to be reachable from the internet
#
# - Private subnets: No direct internet access
#   Used for: EKS nodes, pods, databases
#   Why: More secure, can't be directly accessed from internet
#   Internet access: Via NAT Gateway (outbound only - can pull images, can't be attacked)
#
# The subnet tags are critical - Kubernetes uses them to know:
# - Which subnets to use for load balancers
# - Which subnets belong to the cluster
# Without these tags, Kubernetes won't know where to place things

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  # Only create VPC if we're not using an existing one
  count = local.should_use_existing ? 0 : 1

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr # e.g., 10.0.0.0/16 gives you 65,536 IP addresses

  # Spread across multiple availability zones for redundancy
  # If one AZ goes down, your cluster keeps running
  azs = var.availability_zones

  # Calculate subnet CIDRs automatically
  # Private: 10.0.0.0/24 (256 IPs), 10.0.1.0/24, etc.
  # Public:  10.0.10.0/24 (256 IPs), 10.0.11.0/24, etc.
  # The +10 offset keeps public and private subnets separate
  private_subnets = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets  = [for k, v in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, k + 10)]

  # NAT Gateway lets private subnets reach the internet
  # Needed for: Pulling Docker images, downloading packages, API calls
  # Cost: ~$32/month per NAT Gateway
  # single_nat_gateway = true: One NAT for all AZs (cheaper, single point of failure)
  # single_nat_gateway = false: One NAT per AZ (more reliable, more expensive)
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  # DNS settings - required for Kubernetes service discovery
  # Without these, pods can't resolve service names like "my-app.default.svc.cluster.local"
  enable_dns_hostnames = true
  enable_dns_support   = true

  # These tags tell Kubernetes which subnets to use
  # "kubernetes.io/role/elb" = external load balancers go in public subnets
  # "kubernetes.io/role/internal-elb" = internal load balancers go in private subnets
  # "kubernetes.io/cluster/NAME" = "shared" means this subnet can be used by the cluster
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }

  tags = var.tags
}

# ============================================================================
# EKS Cluster
# ============================================================================
# 
# This is the Kubernetes control plane. It's what kubectl talks to.
# AWS manages this for you - you don't need to worry about etcd, API server,
# scheduler, etc. AWS handles all the complexity.
#
# The control plane runs across multiple availability zones automatically
# for high availability. If one AZ goes down, the cluster keeps running.
#
# Takes about 10-15 minutes to create. AWS is provisioning the control plane
# infrastructure behind the scenes.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.21" # Using v19 for stable API - v21 has breaking changes that break things

  cluster_name    = var.project_name
  cluster_version = var.eks_cluster_version # Kubernetes version (1.34 is latest as of now)

  # Cluster control plane needs to be in private subnets
  # This is more secure - the API server isn't directly accessible from internet
  # (though we enable public endpoint below for easier access)
  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # Don't manage aws_auth config map via the module
  # The module's way of managing this is deprecated and causes issues
  # We'll manage it ourselves later using the Kubernetes provider
  manage_aws_auth_configmap = false

  # Public endpoint = you can access cluster API from anywhere
  # This makes it easier to use kubectl from your laptop
  # For production, set to false and use VPN/bastion host for better security
  cluster_endpoint_public_access = true

  # IRSA = IAM Roles for Service Accounts
  # This is the modern, secure way to give pods AWS permissions
  # How it works:
  # 1. EKS creates an OIDC provider (bridge between Kubernetes and AWS)
  # 2. You create an IAM role that trusts this OIDC provider
  # 3. Pods use a service account that references the IAM role
  # 4. When the pod runs, it automatically assumes the IAM role
  # 
  # Old way: Store AWS credentials in pods (security risk)
  # New way: IRSA (what we're using - no credentials in pods)
  enable_irsa = true

  # Send cluster logs to CloudWatch
  # Useful for debugging when things go wrong
  # You can see API server logs, scheduler logs, etc.
  create_cloudwatch_log_group = true

  # Phase 8: EKS control-plane logs (includes audit)
  cluster_enabled_log_types = var.enable_eks_control_plane_audit_logs ? [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ] : []

  # Node groups are the EC2 instances that run your pods
  # "Managed" means AWS handles the lifecycle:
  # - Auto-scaling (add/remove nodes based on load)
  # - Updates (rolling updates when you change config)
  # - Health checks (replace unhealthy nodes)
  #
  # You can also use "self-managed" node groups, but then you handle all that yourself
  eks_managed_node_groups = {
    main = {
      # Scaling configuration
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size # Start with this many nodes

      # Instance types - you can list multiple and AWS picks based on availability
      # t3.small: 2 vCPU, 2GB RAM - fine for learning (~$15/month)
      # t3.medium: 2 vCPU, 4GB RAM - better for production (~$30/month)
      instance_types = var.node_group_instance_types

      # ON_DEMAND = regular instances, guaranteed availability
      # SPOT = up to 70% cheaper, but can be terminated with 2 minutes notice
      # SPOT is fine for dev/test, ON_DEMAND for production
      capacity_type = "ON_DEMAND"

      # We're not using a custom launch template
      # The module's defaults are fine for most cases
      # You'd only need a custom template for special requirements
      use_custom_launch_template = false

      # Disk size for nodes (default is 20GB)
      # Increase if you're running large containers or need more space
      # Each node gets this much storage
      disk_size = 20

      # Labels help you identify nodes
      # Useful for pod placement - you can say "run this pod only on nodes with label X"
      labels = {
        NodeGroup = "main"
      }

      tags = {
        Name = "${var.project_name}-node-group"
      }
    }
  }

  tags = var.tags
}

# ============================================================================
# EKS Add-ons
# ============================================================================
# 
# These are essential Kubernetes components that AWS manages for you.
# Without these, your cluster won't work properly.
#
# We don't specify versions - AWS automatically picks versions compatible
# with your Kubernetes version. If you try to specify a version manually,
# you might pick an incompatible one and break things. Let AWS handle it.

# VPC CNI (Container Network Interface)
# This gives pods IP addresses from your VPC
# Without this, pods can't talk to each other or reach the internet
# It's what makes Kubernetes networking work on AWS
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = module.eks.cluster_name
  addon_name   = "vpc-cni"
  tags         = var.tags
}

# CoreDNS
# This is the DNS server for your cluster
# When you create a service named "my-app", other pods can reach it via
# "my-app.default.svc.cluster.local"
# Without this, service discovery doesn't work
resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"
  tags         = var.tags
}

# kube-proxy
# Network proxy that routes traffic to pods
# Makes services work - when you access a service, kube-proxy routes
# the traffic to one of the pods behind that service
resource "aws_eks_addon" "kube_proxy" {
  cluster_name = module.eks.cluster_name
  addon_name   = "kube-proxy"
  tags         = var.tags
}

# EBS CSI Driver
# Lets pods use EBS volumes for persistent storage
# Needed if you want to run databases or need file storage that persists
# This one needs an IAM role (see below) because it creates/attaches volumes
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  tags                     = var.tags
}

# ============================================================================
# IAM Role for EBS CSI Driver (IRSA)
# ============================================================================
# 
# IRSA = IAM Roles for Service Accounts
# This is how we give the EBS CSI driver permission to create/attach volumes
#
# How it works:
# 1. EKS creates an OIDC provider (bridge between Kubernetes and AWS)
# 2. We create an IAM role that trusts this OIDC provider
# 3. The EBS CSI pod uses a service account that references this role
# 4. When the pod runs, it automatically assumes this IAM role
# 5. The role has permissions to create/attach EBS volumes
#
# This is the secure way to give pods AWS permissions. The old way was to
# store AWS credentials in pods, which is a security risk.

# Policy document that defines who can assume this role
# We're saying "only the EBS CSI service account can assume this role"
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"] # This is the IRSA action
    effect  = "Allow"

    # Only allow the specific service account in kube-system namespace
    # This is the service account that the EBS CSI driver uses
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    # Verify the audience is correct (security check)
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # The OIDC provider is the "principal" - it's what vouches for the pod
    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

# The IAM role that EBS CSI will assume
resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${var.project_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json
  tags               = var.tags
}

# Attach the AWS-managed policy that gives permissions to create/attach EBS volumes
# AWS provides this policy - it has all the permissions the EBS CSI driver needs
# You could write your own policy, but this one is tested and maintained by AWS
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ============================================================================
# Kubernetes Provider (for managing aws-auth configmap)
# ============================================================================
#
# This provider lets Terraform manage Kubernetes resources (like configmaps).
# We use it to automatically add your IAM user to aws-auth so the AWS console
# can view nodes.
#
# The exec method dynamically gets an authentication token when needed.
# This works even though the cluster doesn't exist at provider initialization time
# because the token is fetched on-demand.

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # Use AWS CLI to get authentication token
  # This is the same thing kubectl does when you run aws eks update-kubeconfig
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Helm provider (used for installing ArgoCD and other add-ons)
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

# ============================================================================
# AWS Auth ConfigMap (for console visibility)
# ============================================================================
#
# The AWS console needs Kubernetes RBAC permissions to view nodes.
# This configmap maps your IAM user to Kubernetes RBAC groups.
#
# If you don't provide admin_iam_user_arn, this resource is skipped.
# You can still use kubectl (which works fine), but the console won't show nodes.
#
# We preserve existing node group roles so we don't break anything.

# Get existing aws-auth configmap data
# We need this so we don't overwrite the node group roles that EKS created
data "kubernetes_config_map" "aws_auth" {
  count = var.admin_iam_user_arn != "" ? 1 : 0
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  depends_on = [module.eks] # Wait for cluster to exist
}

# Merge existing mapRoles with new mapUsers
locals {
  # Parse existing mapRoles from the configmap
  # These are the roles that let nodes join the cluster
  # We keep these so nodes can still join
  existing_map_roles = var.admin_iam_user_arn != "" ? (
    try(yamldecode(data.kubernetes_config_map.aws_auth[0].data["mapRoles"]), [])
  ) : []

  # Create mapUsers entry for admin user
  # system:masters gives full access to the cluster
  admin_map_users = var.admin_iam_user_arn != "" ? [
    {
      userarn  = var.admin_iam_user_arn
      username = "admin"
      groups   = ["system:masters"] # Full cluster access
    }
  ] : []
}

# Update aws-auth configmap with admin user
# This makes your IAM user visible to Kubernetes RBAC
resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = var.admin_iam_user_arn != "" ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  # Combine existing roles (for nodes) with new users (for console access)
  data = {
    mapRoles = yamlencode(local.existing_map_roles)
    mapUsers = yamlencode(local.admin_map_users)
  }

  force = true # Force update even if configmap exists (in case we're updating it)

  # Wait for cluster and add-ons to be ready before trying to modify configmap
  depends_on = [
    module.eks,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    aws_eks_addon.kube_proxy
  ]
}

