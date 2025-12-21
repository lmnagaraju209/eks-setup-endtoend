# ============================================================================
# Phase 7: Monitoring & Observability (installed during infra provisioning)
# ============================================================================

variable "enable_monitoring" {
  description = "If true, install kube-prometheus-stack (Prometheus, Grafana, Alertmanager) via Helm."
  type        = bool
  default     = true
}

variable "monitoring_namespace" {
  description = "Namespace for monitoring stack."
  type        = string
  default     = "monitoring"
}

variable "kube_prometheus_stack_chart_version" {
  description = "Helm chart version for kube-prometheus-stack (prometheus-community/kube-prometheus-stack)."
  type        = string
  default     = "66.3.0"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. If empty, a random password will be generated."
  type        = string
  default     = ""
  sensitive   = true
}

variable "grafana_ingress_enabled" {
  description = "If true, create an Ingress for Grafana (requires an ingress controller)."
  type        = bool
  default     = false
}

variable "grafana_ingress_host" {
  description = "Hostname for Grafana ingress (required if grafana_ingress_enabled=true)."
  type        = string
  default     = ""
}

variable "grafana_ingress_class_name" {
  description = "IngressClass name for Grafana ingress (e.g. 'alb' for AWS Load Balancer Controller)."
  type        = string
  default     = "alb"
}

variable "grafana_ingress_annotations" {
  description = "Ingress annotations for Grafana ingress."
  type        = map(string)
  default     = {}
}

# Alerting (Alertmanager) - optional integrations
variable "alertmanager_slack_webhook_url" {
  description = "Slack webhook URL for Alertmanager. If empty, Slack receiver is not configured."
  type        = string
  default     = ""
  sensitive   = true
}

variable "alertmanager_slack_channel" {
  description = "Slack channel name (e.g. '#alerts'). Used only if alertmanager_slack_webhook_url is set."
  type        = string
  default     = "#alerts"
}

variable "alertmanager_slack_username" {
  description = "Slack username shown for Alertmanager notifications."
  type        = string
  default     = "alertmanager"
}

resource "kubernetes_namespace" "monitoring" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name = var.monitoring_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "random_password" "grafana_admin" {
  count = (var.enable_monitoring && var.grafana_admin_password == "") ? 1 : 0

  length  = 20
  special = true
}

locals {
  grafana_admin_password_effective = var.grafana_admin_password != "" ? var.grafana_admin_password : (
    var.enable_monitoring ? random_password.grafana_admin[0].result : ""
  )
}

resource "helm_release" "kube_prometheus_stack" {
  count = var.enable_monitoring ? 1 : 0

  name       = "kube-prometheus-stack"
  namespace  = var.monitoring_namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version

  create_namespace = false

  # Non-atomic allows partial success - we can fix issues manually if needed
  atomic          = false # Changed to false to prevent rollback on timeout
  cleanup_on_fail = false # Keep resources even if install fails
  wait            = true
  timeout         = 1800 # Increased to 30 minutes for initial install

  values = [
    yamlencode({
      grafana = {
        adminPassword = local.grafana_admin_password_effective
        "grafana.ini" = {
          server = {
            root_url            = "https://${var.application_host}/monitoring/"
            serve_from_sub_path = true
          }
        }
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = var.grafana_ingress_enabled
          ingressClassName = var.grafana_ingress_class_name
          annotations      = var.grafana_ingress_annotations
          hosts            = var.grafana_ingress_host != "" ? [var.grafana_ingress_host] : []
          path             = "/"
          pathType         = "Prefix"
        }
      }
      prometheus = {
        prometheusSpec = {
          retention = "7d"
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          retention = "120h"
        }
        # Important: keep types consistent (Terraform requires both branches to have the same keys)
        config = var.alertmanager_slack_webhook_url != "" ? {
          global = {}
          route = {
            receiver        = "slack"
            group_by        = ["alertname", "namespace"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "3h"
            routes          = []
          }
          receivers = [
            {
              name = "slack"
              slack_configs = [
                {
                  api_url       = var.alertmanager_slack_webhook_url
                  channel       = var.alertmanager_slack_channel
                  username      = var.alertmanager_slack_username
                  send_resolved = true
                  title         = "{{ range .Alerts }}{{ .Annotations.summary }}\\n{{ end }}"
                  text          = "{{ range .Alerts }}*{{ .Labels.severity }}* {{ .Annotations.description }}\\n{{ end }}"
                }
              ]
            }
          ]
          } : {
          global = {}
          route = {
            receiver        = "null"
            group_by        = ["alertname", "namespace"]
            group_wait      = "30s"
            group_interval  = "5m"
            repeat_interval = "3h"
            routes          = []
          }
          receivers = [
            {
              name          = "null"
              slack_configs = []
            }
          ]
        }
      }
    })
  ]

  # Wait for cluster, add-ons (especially CoreDNS), and node groups to be ready
  depends_on = [
    module.eks,
    aws_eks_addon.coredns, # CoreDNS must be ready for service discovery
    aws_eks_addon.vpc_cni, # VPC CNI must be ready for networking
    kubernetes_namespace.monitoring
  ]
}


