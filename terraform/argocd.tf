# ============================================================================
# Phase 5: ArgoCD (installed during infra provisioning)
# ============================================================================

variable "enable_argocd" {
  description = "If true, install ArgoCD into the EKS cluster during terraform apply."
  type        = bool
  default     = true
}

variable "argocd_chart_version" {
  description = "Helm chart version for ArgoCD (argo/argo-cd)."
  type        = string
  default     = "7.8.2"
}

variable "argocd_namespace" {
  description = "Namespace to install ArgoCD into."
  type        = string
  default     = "argocd"
}

variable "argocd_ingress_enabled" {
  description = "If true, create an Ingress for ArgoCD server (you must have an ingress controller installed)."
  type        = bool
  default     = false
}

variable "argocd_ingress_host" {
  description = "Hostname for ArgoCD ingress (required if argocd_ingress_enabled=true)."
  type        = string
  default     = ""
}

variable "argocd_ingress_class_name" {
  description = "IngressClass name for ArgoCD ingress (e.g. 'alb' for AWS Load Balancer Controller)."
  type        = string
  default     = "alb"
}

variable "argocd_ingress_annotations" {
  description = "Ingress annotations for ArgoCD server ingress."
  type        = map(string)
  default     = {}
}

resource "kubernetes_namespace" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  namespace  = var.argocd_namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  create_namespace = false

  # Make initial install more stable in fresh clusters
  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 900

  values = [
    yamlencode({
      server = {
        extraArgs = [
          "--rootpath",
          "/argocd",
          "--basehref",
          "/argocd"
        ]
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = var.argocd_ingress_enabled
          ingressClassName = var.argocd_ingress_class_name
          annotations      = var.argocd_ingress_annotations
          hosts            = var.argocd_ingress_host != "" ? [var.argocd_ingress_host] : []
          paths            = ["/"]
          pathType         = "Prefix"
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace.argocd
  ]
}

# The chart creates this secret on first install
data "kubernetes_secret" "argocd_initial_admin" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = var.argocd_namespace
  }

  depends_on = [helm_release.argocd]
}


