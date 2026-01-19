# ============================================================================
# Application domain + Nginx Ingress with Self-Signed Certificate (Route53)
#
# Target URLs:
# - https://application.jumptotech.net/            (frontend)
# - https://application.jumptotech.net/argocd      (ArgoCD)
# - https://application.jumptotech.net/monitoring  (Grafana)
#
# Uses nginx ingress controller with self-signed certificate for HTTPS.
# For production, use ACM certificates with ALB (use_acm_certificate = true)
# ============================================================================

variable "route53_zone_name" {
  description = "Route53 hosted zone name (e.g. 'jumptotech.net')."
  type        = string
  default     = ""
}

variable "application_host" {
  description = "Fully-qualified domain name for the application entrypoint."
  type        = string
  default     = ""
}

variable "enable_public_domain_ingress" {
  description = "If true, provision ALB ingresses + Route53 record for application_host."
  type        = bool
  default     = false
}

variable "use_acm_certificate" {
  description = "If true, use ACM certificate with ALB for HTTPS. If false, use nginx ingress with self-signed cert."
  type        = bool
  default     = false
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

# ACM Certificate (optional - only if use_acm_certificate = true)
resource "aws_acm_certificate" "application" {
  count             = (var.enable_public_domain_ingress && var.use_acm_certificate) ? 1 : 0
  domain_name       = var.application_host
  validation_method = "DNS"
  tags              = var.tags
}

resource "aws_route53_record" "application_cert_validation" {
  for_each = (var.enable_public_domain_ingress && var.use_acm_certificate) ? {
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
  count                   = (var.enable_public_domain_ingress && var.use_acm_certificate) ? 1 : 0
  certificate_arn         = aws_acm_certificate.application[0].arn
  validation_record_fqdns = [for r in aws_route53_record.application_cert_validation : r.fqdn]
}

# AWS Load Balancer Controller
variable "enable_aws_load_balancer_controller" {
  description = "Install AWS Load Balancer Controller via Helm."
  type        = bool
  default     = false
}

variable "aws_load_balancer_controller_chart_version" {
  description = "Helm chart version for aws-load-balancer-controller."
  type        = string
  default     = "1.8.2"
}

# Note: kube-system namespace already exists in all Kubernetes clusters, so we don't create it
# The AWS Load Balancer Controller will be installed in the existing kube-system namespace

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  count = (var.enable_public_domain_ingress && var.enable_aws_load_balancer_controller) ? 1 : 0

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

  # Non-atomic allows partial success - we can fix issues manually if needed
  atomic          = false # Changed to false to prevent rollback on timeout
  cleanup_on_fail = false # Keep resources even if install fails
  wait            = true
  timeout         = 1800 # Increased to 30 minutes for initial install

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

  # Wait for cluster and add-ons (especially CoreDNS and VPC CNI) to be ready
  depends_on = [
    module.eks,
    aws_eks_addon.coredns, # CoreDNS must be ready for service discovery
    aws_eks_addon.vpc_cni, # VPC CNI must be ready for networking
    kubernetes_service_account.aws_load_balancer_controller,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

# ============================================================================
# Self-Signed Certificate for Nginx Ingress (when use_acm_certificate = false)
# ============================================================================

resource "tls_private_key" "self_signed" {
  count     = (var.enable_public_domain_ingress && !var.use_acm_certificate) ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "application" {
  count           = (var.enable_public_domain_ingress && !var.use_acm_certificate) ? 1 : 0
  private_key_pem = tls_private_key.self_signed[0].private_key_pem

  subject {
    common_name  = var.application_host
    organization = "TaskManager"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_secret" "self_signed_tls" {
  count = (var.enable_public_domain_ingress && !var.use_acm_certificate) ? 1 : 0

  metadata {
    name      = "application-self-signed-tls"
    namespace = "default"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.application[0].cert_pem
    "tls.key" = tls_private_key.self_signed[0].private_key_pem
  }

  depends_on = [module.eks]
}

# ============================================================================
# Nginx Ingress Controller (when use_acm_certificate = false)
# ============================================================================

variable "nginx_ingress_chart_version" {
  description = "Helm chart version for nginx-ingress."
  type        = string
  default     = "4.10.2"
}

resource "kubernetes_namespace" "ingress_nginx" {
  count = (var.enable_public_domain_ingress && !var.use_acm_certificate) ? 1 : 0

  metadata {
    name = "ingress-nginx"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "nginx_ingress" {
  count = (var.enable_public_domain_ingress && !var.use_acm_certificate) ? 1 : 0

  name       = "nginx-ingress"
  namespace  = kubernetes_namespace.ingress_nginx[0].metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.nginx_ingress_chart_version

  atomic          = false
  cleanup_on_fail = false
  wait            = true
  timeout         = 600

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"          = var.alb_scheme
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          }
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    aws_eks_addon.coredns,
    aws_eks_addon.vpc_cni,
    kubernetes_namespace.ingress_nginx
  ]
}

locals {
  # Use HTTPS with ACM cert if enabled, otherwise use nginx with self-signed cert
  alb_common_annotations = var.use_acm_certificate ? {
    "kubernetes.io/ingress.class"               = "alb"
    "alb.ingress.kubernetes.io/scheme"          = var.alb_scheme
    "alb.ingress.kubernetes.io/target-type"     = "ip"
    "alb.ingress.kubernetes.io/group.name"      = var.alb_ingress_group_name
    "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTPS\":443}]"
    "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate_validation.application[0].certificate_arn
    "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
    } : {
    "kubernetes.io/ingress.class" = "nginx"
  }

  nginx_ingress_class = var.use_acm_certificate ? "alb" : "nginx"

  # Build dependency lists - always include all possible dependencies
  # Terraform will handle conditional resources gracefully
  ingress_dependencies = var.use_acm_certificate ? [
    "helm_release.aws_load_balancer_controller"
    ] : [
    "helm_release.nginx_ingress",
    "kubernetes_secret.self_signed_tls"
  ]
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
    ingress_class_name = local.nginx_ingress_class
    dynamic "tls" {
      for_each = var.use_acm_certificate ? [] : [1]
      content {
        hosts       = [var.application_host]
        secret_name = kubernetes_secret.self_signed_tls[0].metadata[0].name
      }
    }
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

  # Dependencies handled via resource creation order
  # If use_acm_certificate=true, depends on ALB controller
  # If use_acm_certificate=false, depends on nginx ingress and TLS secret
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
      # Nginx annotations for ArgoCD subpath - forward path as-is
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    })
  }

  spec {
    ingress_class_name = local.nginx_ingress_class
    dynamic "tls" {
      for_each = var.use_acm_certificate ? [] : [1]
      content {
        hosts       = [var.application_host]
        secret_name = kubernetes_secret.self_signed_tls[0].metadata[0].name
      }
    }
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

  # Dependencies handled via resource creation order
  # Always depends on ArgoCD, plus ALB controller or nginx ingress based on use_acm_certificate
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
    ingress_class_name = local.nginx_ingress_class
    dynamic "tls" {
      for_each = var.use_acm_certificate ? [] : [1]
      content {
        hosts       = [var.application_host]
        secret_name = kubernetes_secret.self_signed_tls[0].metadata[0].name
      }
    }
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

  # Dependencies handled via resource creation order
  # Always depends on Prometheus stack, plus ALB controller or nginx ingress based on use_acm_certificate
}

# Local value to safely get Load Balancer hostname (ALB or NLB)
locals {
  lb_hostname = try(
    kubernetes_ingress_v1.application_root[0].status[0].load_balancer[0].ingress[0].hostname,
    ""
  )
}

# Route53 CNAME (works for subdomain like application.jumptotech.net)
# Note: Only create if Load Balancer hostname is available (may take a few minutes)
resource "aws_route53_record" "application_cname" {
  count   = var.enable_public_domain_ingress ? 1 : 0
  zone_id = data.aws_route53_zone.primary[0].zone_id
  name    = var.application_host
  type    = "CNAME"
  ttl     = 300
  records = [local.lb_hostname != "" ? local.lb_hostname : "placeholder.example.com"]

  # Dependencies handled via resource creation order
  # Always depends on root ingress, plus ALB controller or nginx ingress based on use_acm_certificate

  lifecycle {
    ignore_changes        = [records]
    create_before_destroy = true
  }
}


