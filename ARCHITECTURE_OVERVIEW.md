# EKS Architecture Overview

## High-Level Flow

```
Developer → GitHub → GitHub Actions → ECR → ArgoCD → EKS → Users
```

## Component Flow

**Development**: Code commit triggers GitHub Actions  
**Build**: Actions builds Docker image, pushes to ECR  
**Deploy**: Actions updates Helm chart in Git  
**Sync**: ArgoCD detects change, syncs to EKS  
**Run**: Applications run on EKS nodes  
**Access**: Users hit services via Load Balancer  

## Architecture

```
┌─────────────────────────────────────────┐
│         GitHub Repository               │
│  ┌──────────┐  ┌──────────┐           │
│  │   App    │  │   Helm   │           │
│  │   Code   │  │  Charts  │           │
│  └──────────┘  └──────────┘           │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│      GitHub Actions CI/CD               │
│  1. Build & Test                        │
│  2. Build Docker Image                  │
│  3. Push to ECR                         │
│  4. Update Helm Chart                   │
│  5. Commit to Git                       │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│         AWS Infrastructure              │
│  ┌──────────┐  ┌──────────┐           │
│  │   VPC    │  │   EKS    │           │
│  │          │  │  Cluster │           │
│  └──────────┘  └──────────┘           │
│  ┌──────────┐  ┌──────────┐           │
│  │   ECR    │  │   ALB    │           │
│  └──────────┘  └──────────┘           │
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│      Kubernetes Cluster (EKS)           │
│                                         │
│  ┌───────────────────────────────┐     │
│  │      ArgoCD Namespace         │     │
│  │  ArgoCD Server + Controller   │     │
│  └───────────────────────────────┘     │
│                                         │
│  ┌───────────────────────────────┐     │
│  │    Application Namespaces     │     │
│  │  ┌──────────┐  ┌──────────┐  │     │
│  │  │ Service1 │  │ Service2 │  │     │
│  │  └──────────┘  └──────────┘  │     │
│  └───────────────────────────────┘     │
│                                         │
│  ┌───────────────────────────────┐     │
│  │    Monitoring Namespace       │     │
│  │  Prometheus + Grafana         │     │
│  └───────────────────────────────┘     │
└─────────────────────────────────────────┘
```

## Data Flow

**Request Flow**:  
User → ALB → Ingress → Service → Pod → Application

**Deployment Flow**:  
Code Change → GitHub Actions → ECR → Helm Chart Update → Git → ArgoCD → EKS

**GitOps Flow**:  
Git (Helm Charts) → ArgoCD → Kubernetes API → Deploy

**Monitoring Flow**:  
Apps → Metrics → Prometheus → Grafana  
Apps → Logs → Fluent Bit → CloudWatch/Loki

## Key Components

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Infrastructure | Terraform | Provision AWS resources |
| Container Registry | ECR | Store Docker images |
| Orchestration | EKS | Run containers |
| Package Manager | Helm | Deploy K8s apps |
| CI/CD | GitHub Actions | Build and test |
| GitOps | ArgoCD | Continuous deployment |
| Monitoring | Prometheus + Grafana | Metrics and dashboards |
| Logging | CloudWatch/Loki | Centralized logs |
| Networking | VPC, ALB, Ingress | Connectivity |
| Security | IAM, RBAC, Secrets | Access control |

## Environments

**Dev**: Auto-deploy, minimal resources, basic monitoring  
**Staging**: Manual approval, production-like, full monitoring  
**Prod**: High availability, multi-AZ, security hardened, comprehensive monitoring

## High Availability

- EKS control plane: Multi-AZ (AWS managed)
- Node groups: Spread across AZs
- Application pods: Replicas across nodes
- Load balancer: Multi-AZ
- ArgoCD: HA mode (multiple replicas)

## Security Layers

1. **Network**: VPC, Security Groups, Network Policies
2. **Access**: IAM, RBAC, Service Accounts
3. **Secrets**: AWS Secrets Manager, K8s Secrets (encrypted)
4. **Container**: Image scanning, security policies
5. **Runtime**: Pod Security Standards, Network Policies
6. **Compliance**: Audit logging, scanning

## Scalability

- **HPA**: Scale pods based on CPU/memory
- **Cluster Autoscaler**: Add/remove nodes automatically
- **VPA**: Optimize resource requests (optional)
- **Load Balancing**: Distribute across pods

## Design Decisions

**Why Terraform?** Infrastructure as code, version control, repeatable  
**Why EKS?** Managed Kubernetes, less ops overhead  
**Why Helm?** Standard packaging, templating, versioning  
**Why ArgoCD?** GitOps, declarative, sync monitoring  
**Why Prometheus?** Standard metrics, rich ecosystem  
**Why GitHub Actions?** Integrated, no extra setup
