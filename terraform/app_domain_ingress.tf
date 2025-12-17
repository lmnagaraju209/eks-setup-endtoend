# ============================================================================
# Application domain + ALB ingress (Route53 + ACM + AWS Load Balancer Controller)
#
# Target URLs:
# - https://application.jumptotech.net/            (frontend)
# - https://application.jumptotech.net/argocd      (ArgoCD)
# - https://application.jumptotech.net/monitoring  (Grafana)
# ============================================================================

variable "route53_zone_name" {
  description = "Route53 hosted zone name (e.g. 'jumptotech.net')."
  type        = string
  default     = "jumptotech.net"
}

variable "application_host" {
  description = "Fully-qualified domain name for the application entrypoint."
  type        = string
  default     = "application.jumptotech.net"
}

variable "enable_public_domain_ingress" {
  description = "If true, provision ACM cert + ALB ingresses + Route53 record for application_host."
  type        = bool
  default     = true
}

variable "alb_ingress_group_name" {
  description = "ALB ingress group name so multiple ingresses share one ALB."
  type        = string
  default     = "application"
}

variable "alb_scheme" {
  description = "ALB scheme."
  type        = string
  default     = "internet-facing"
}

data "aws_route53_zone" "primary" {
  count        = var.enable_public_domain_ingress ? 1 : 0
  name         = "${var.route53_zone_name}."
  private_zone = false
}

resource "aws_acm_certificate" "application" {
  count             = var.enable_public_domain_ingress ? 1 : 0
  domain_name       = var.application_host
  validation_method = "DNS"
  tags              = var.tags
}

resource "aws_route53_record" "application_cert_validation" {
  for_each = var.enable_public_domain_ingress ? {
    for dvo in aws_acm_certificate.application[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "application" {
  count                   = var.enable_public_domain_ingress ? 1 : 0
  certificate_arn         = aws_acm_certificate.application[0].arn
  validation_record_fqdns = [for r in aws_route53_record.application_cert_validation : r.fqdn]
}

# AWS Load Balancer Controller
variable "enable_aws_load_balancer_controller" {
  description = "Install AWS Load Balancer Controller via Helm."
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller."
  type        = string
  default     = "1.8.2"
}

resource "kubernetes_namespace" "aws_load_balancer_controller" {
  count = (var.enable_public_domain_ingress && var.enable_aws_load_balancer_controller) ? 1 : 0

  metadata {
    name = "kube-system"
  }
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  count = (var.enable_public_domain_ingress && var.enable_aws_load_balancer_controller) ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  count              = (var.enable_public_domain_ingress && var.enable_aws_load_balancer_controller) ? 1 : 0
  name               = "${var.project_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role[0].json
  tags               = var.tags
}

# AWS-managed policy recommended by AWS (controller uses this name)
resource "aws_iam_policy" "aws_load_balancer_controller" {
  count = (var.enable_public_domain_ingress && var.enable_aws_load_balancer_controller) ? 1 : 0

  name   = "${var.project_name}-aws-load-balancer-controller"
  policy = file("${path.module}/policies/aws-load-balancer-controller.json")
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count      = (var.enable_public_domain_ingress && var.enable_aws_load_balancer_controller) ? 1 : 0
  role       = aws_iam_role.aws_load_balancer_controller[0].name
  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
}

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  count = (var.enable_public_domain_ingress && var.enable_aws_load_balancer_controller) ? 1 : 0

  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller[0].arn
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "aws_load_balancer_controller" {
  count = (var.enable_public_domain_ingress && var.enable_aws_load_balancer_controller) ? 1 : 0

  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 900

  values = [
    yamlencode({
      clusterName = module.eks.cluster_name
      region      = var.aws_region
      vpcId       = local.vpc_id
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.aws_load_balancer_controller[0].metadata[0].name
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.aws_load_balancer_controller,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

locals {
  alb_common_annotations = {
    "kubernetes.io/ingress.class"               = "alb"
    "alb.ingress.kubernetes.io/scheme"          = var.alb_scheme
    "alb.ingress.kubernetes.io/target-type"     = "ip"
    "alb.ingress.kubernetes.io/group.name"      = var.alb_ingress_group_name
    "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate_validation.application[0].certificate_arn
  }
}

# Root ingress (frontend)
resource "kubernetes_ingress_v1" "application_root" {
  count = var.enable_public_domain_ingress ? 1 : 0

  metadata {
    name      = "application-root"
    namespace = "default"
    annotations = merge(local.alb_common_annotations, {
      "alb.ingress.kubernetes.io/group.order"      = "10"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
    })
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = var.application_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "eks-setup-app-frontend"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller
  ]
}

# ArgoCD ingress (subpath)
resource "kubernetes_ingress_v1" "application_argocd" {
  count = (var.enable_public_domain_ingress && var.enable_argocd) ? 1 : 0

  metadata {
    name      = "application-argocd"
    namespace = var.argocd_namespace
    annotations = merge(local.alb_common_annotations, {
      "alb.ingress.kubernetes.io/group.order"      = "20"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/argocd/healthz"
    })
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = var.application_host
      http {
        path {
          path      = "/argocd"
          path_type = "Prefix"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    helm_release.aws_load_balancer_controller
  ]
}

# Grafana ingress (subpath)
resource "kubernetes_ingress_v1" "application_monitoring" {
  count = (var.enable_public_domain_ingress && var.enable_monitoring) ? 1 : 0

  metadata {
    name      = "application-monitoring"
    namespace = var.monitoring_namespace
    annotations = merge(local.alb_common_annotations, {
      "alb.ingress.kubernetes.io/group.order"      = "30"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/monitoring/api/health"
    })
  }

  spec {
    ingress_class_name = "alb"
    rule {
      host = var.application_host
      http {
        path {
          path      = "/monitoring"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack,
    helm_release.aws_load_balancer_controller
  ]
}

# Route53 CNAME (works for subdomain like application.jumptotech.net)
resource "aws_route53_record" "application_cname" {
  count   = var.enable_public_domain_ingress ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = var.application_host
  type    = "CNAME"
  ttl     = 300
  records = [kubernetes_ingress_v1.application_root[0].status[0].load_balancer[0].ingress[0].hostname]

  depends_on = [kubernetes_ingress_v1.application_root]
}


