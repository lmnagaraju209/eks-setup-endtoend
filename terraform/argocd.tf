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
  # Non-atomic allows partial success - we can fix issues manually if needed
  atomic          = false # Changed to false to prevent rollback on timeout
  cleanup_on_fail = false # Keep resources even if install fails
  wait            = true
  timeout         = 1800 # Increased to 30 minutes for initial install

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

  # Wait for cluster, add-ons (especially CoreDNS), and node groups to be ready
  depends_on = [
    module.eks,
    aws_eks_addon.coredns, # CoreDNS must be ready for service discovery
    aws_eks_addon.vpc_cni, # VPC CNI must be ready for networking
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

# ============================================================================
# Optional: ArgoCD Application (GitOps)
# Creates an Application that monitors Git repo and auto-deploys when Helm values change
# ============================================================================

variable "argocd_application_enabled" {
  description = "If true, create an ArgoCD Application that monitors the Git repo and auto-deploys the Helm chart. Requires argocd_git_repo_url to be set."
  type        = bool
  default     = false
}

variable "argocd_git_repo_url" {
  description = "Git repository URL for ArgoCD Application to monitor (e.g., https://github.com/user/repo.git). Required if argocd_application_enabled=true."
  type        = string
  default     = ""
}

variable "argocd_application_target_revision" {
  description = "Git branch/tag/commit for ArgoCD Application to monitor (e.g., main, refs/heads/main)."
  type        = string
  default     = "main"
}

variable "argocd_application_namespace" {
  description = "Kubernetes namespace where the application will be deployed (via ArgoCD Application)."
  type        = string
  default     = "default"
}

variable "argocd_application_sync_policy" {
  description = "ArgoCD sync policy: 'automated' (auto-sync on Git changes) or 'manual' (requires manual sync)."
  type        = string
  default     = "automated"
  validation {
    condition     = contains(["automated", "manual"], var.argocd_application_sync_policy)
    error_message = "argocd_application_sync_policy must be 'automated' or 'manual'."
  }
}

resource "kubernetes_manifest" "argocd_application" {
  count = var.enable_argocd && var.argocd_application_enabled && var.argocd_git_repo_url != "" ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "taskmanager"
      namespace = var.argocd_namespace
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.argocd_git_repo_url
        targetRevision = var.argocd_application_target_revision
        path           = "helm/eks-setup-app"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_application_namespace
      }
      syncPolicy = var.argocd_application_sync_policy == "automated" ? {
        automated = {
          prune      = true
          selfHeal   = true
          allowEmpty = false
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      } : {
        syncOptions = [
          "CreateNamespace=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}


