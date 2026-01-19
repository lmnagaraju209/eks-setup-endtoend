# ============================================================================
# Phase 8: Secrets Management (External Secrets Operator + AWS Secrets Manager)
# ============================================================================

variable "enable_external_secrets" {
  description = "If true, install External Secrets Operator (ESO) and configure IRSA so it can read AWS Secrets Manager."
  type        = bool
  default     = false
}

variable "external_secrets_namespace" {
  description = "Namespace to install External Secrets Operator into."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_chart_version" {
  description = "Helm chart version for external-secrets/external-secrets."
  type        = string
  default     = "0.10.7"
}

resource "kubernetes_namespace" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  metadata {
    name = var.external_secrets_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  count = var.enable_external_secrets ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.external_secrets_namespace}:external-secrets"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  count              = var.enable_external_secrets ? 1 : 0
  name               = "${var.project_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "external_secrets_permissions" {
  count = var.enable_external_secrets ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_secrets" {
  count  = var.enable_external_secrets ? 1 : 0
  name   = "${var.project_name}-external-secrets"
  policy = data.aws_iam_policy_document.external_secrets_permissions[0].json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  count      = var.enable_external_secrets ? 1 : 0
  role       = aws_iam_role.external_secrets[0].name
  policy_arn = aws_iam_policy.external_secrets[0].arn
}

resource "kubernetes_service_account" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  metadata {
    name      = "external-secrets"
    namespace = var.external_secrets_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets[0].arn
    }
  }

  depends_on = [
    module.eks,
    kubernetes_namespace.external_secrets
  ]
}

resource "helm_release" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name       = "external-secrets"
  namespace  = var.external_secrets_namespace
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.external_secrets_chart_version

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
        name   = kubernetes_service_account.external_secrets[0].metadata[0].name
      }
      installCRDs = true
    })
  ]

  # Wait for cluster, add-ons, and AWS Load Balancer Controller to be ready
  depends_on = [
    module.eks,
    aws_eks_addon.coredns, # CoreDNS must be ready for service discovery
    aws_eks_addon.vpc_cni, # VPC CNI must be ready for networking
    kubernetes_service_account.external_secrets,
    helm_release.aws_load_balancer_controller,
    aws_iam_role_policy_attachment.external_secrets
  ]
}


