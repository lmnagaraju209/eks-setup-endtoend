# ============================================================================
# Phase 7: Logging (Fluent Bit -> CloudWatch Logs) installed via Terraform
# ============================================================================

variable "enable_logging" {
  description = "If true, install aws-for-fluent-bit and ship pod logs to CloudWatch Logs."
  type        = bool
  default     = false
}

variable "logging_namespace" {
  description = "Namespace to deploy Fluent Bit into (kube-system is typical on EKS)."
  type        = string
  default     = "kube-system"
}

variable "fluent_bit_chart_version" {
  description = "Helm chart version for aws-for-fluent-bit."
  type        = string
  default     = "0.1.34"
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch Logs log group name for container logs."
  type        = string
  default     = ""
}

variable "cloudwatch_log_retention_in_days" {
  description = "Retention (days) for the CloudWatch log group (if Terraform creates it)."
  type        = number
  default     = 14
}

locals {
  cloudwatch_log_group_name_effective = var.cloudwatch_log_group_name != "" ? var.cloudwatch_log_group_name : "/aws/eks/${var.project_name}/containers"
}

resource "aws_cloudwatch_log_group" "containers" {
  count             = var.enable_logging ? 1 : 0
  name              = local.cloudwatch_log_group_name_effective
  retention_in_days = var.cloudwatch_log_retention_in_days
  tags              = var.tags
}

resource "kubernetes_service_account" "fluent_bit" {
  count = var.enable_logging ? 1 : 0

  metadata {
    name      = "fluent-bit"
    namespace = var.logging_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit.arn
    }
    labels = {
      "app.kubernetes.io/name"       = "fluent-bit"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "aws_for_fluent_bit" {
  count = var.enable_logging ? 1 : 0

  name       = "aws-for-fluent-bit"
  namespace  = var.logging_namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = var.fluent_bit_chart_version

  create_namespace = false

  # Non-atomic allows partial success - we can fix issues manually if needed
  atomic          = false # Changed to false to prevent rollback on timeout
  cleanup_on_fail = false # Keep resources even if install fails
  wait            = true
  timeout         = 1800 # Increased to 30 minutes for initial install

  values = [
    yamlencode({
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.fluent_bit[0].metadata[0].name
      }
      cloudWatch = {
        region           = data.aws_region.current.name
        logGroupName     = local.cloudwatch_log_group_name_effective
        logStreamPrefix  = "from-fluent-bit-"
        logRetentionDays = var.cloudwatch_log_retention_in_days
      }
    })
  ]

  # Wait for cluster and add-ons (especially CoreDNS) to be ready
  depends_on = [
    module.eks,
    aws_eks_addon.coredns, # CoreDNS must be ready for service discovery
    aws_eks_addon.vpc_cni, # VPC CNI must be ready for networking
    kubernetes_service_account.fluent_bit,
    aws_cloudwatch_log_group.containers
  ]
}


