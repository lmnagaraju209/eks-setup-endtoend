# Phase 1 vs Phase 5: ArgoCD Installation Clarification

## Original Project Plan (PROJECT_PLAN.md)

According to the original plan:

### Phase 1: Infrastructure (Terraform)
- ✅ VPC & Networking
- ✅ EKS Cluster
- ✅ EKS Add-ons (VPC CNI, CoreDNS, kube-proxy)
- ✅ IAM & Security (IRSA)
- ✅ Storage (EBS CSI)
- ✅ Testing (kubectl access)
- ❌ **ArgoCD is NOT part of Phase 1**

### Phase 5: ArgoCD (Separate Phase)
- Manual installation via Helm
- Configuration
- Application definitions
- Git integration
- Sync policies

## Current Implementation (What's Actually Done)

**Deviation from Plan**: ArgoCD is installed **during Phase 1's terraform apply**, not as a separate Phase 5 step.

### What Happens During `terraform apply`:

1. **Phase 1 Infrastructure is created:**
   - VPC, EKS cluster, node groups
   - EKS add-ons (VPC CNI, CoreDNS, kube-proxy, EBS CSI)
   - IRSA roles
   - IAM resources

2. **Then, ArgoCD is automatically installed:**
   - ArgoCD Helm chart is installed via Terraform
   - Waits for cluster and add-ons to be ready (`depends_on` ensures proper ordering)
   - Creates ArgoCD namespace
   - Installs ArgoCD server and components

### Why This Approach?

✅ **Benefits:**
- **Infrastructure as Code**: Everything managed declaratively
- **Reproducible**: Same Terraform code = same infrastructure + ArgoCD
- **Automatic**: No manual Helm installation steps
- **Dependency Management**: Terraform ensures ArgoCD installs only after cluster is ready
- **State Management**: ArgoCD installation tracked in Terraform state

⚠️ **Trade-offs:**
- Deviates from original plan (Phase 5 was supposed to be separate)
- ArgoCD installation happens even if you only want infrastructure

### How It Works

The installation sequence:

```terraform
# 1. EKS cluster is created
module.eks → Creates cluster, node groups

# 2. EKS add-ons are installed
aws_eks_addon.vpc_cni → Networking ready
aws_eks_addon.coredns → DNS ready
aws_eks_addon.kube_proxy → Service proxy ready

# 3. ArgoCD is installed (waits for cluster + add-ons)
resource "helm_release" "argocd" {
  depends_on = [
    module.eks,
    aws_eks_addon.coredns,  # Must be ready
    aws_eks_addon.vpc_cni,  # Must be ready
    kubernetes_namespace.argocd
  ]
}
```

### Can You Skip ArgoCD in Phase 1?

Yes! Set in `terraform.tfvars`:

```hcl
enable_argocd = false
```

Then install ArgoCD manually later (following Phase 5 plan) if desired.

## Summary

**Question**: "Does Phase 1 install ArgoCD once infrastructure is ready?"

**Answer**: **Yes, in the current implementation.** 

- ✅ Phase 1 creates infrastructure
- ✅ Phase 1 also installs ArgoCD automatically (if `enable_argocd = true`)
- ✅ ArgoCD installation waits for infrastructure to be ready (via `depends_on`)
- ✅ This is a deviation from the original plan (Phase 5), but it's a better approach for IaC

**To follow the original plan exactly**, set `enable_argocd = false` in `terraform.tfvars` and install ArgoCD manually as Phase 5.

