# Architecture Overview: EKS Kubernetes Setup

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Developer Workflow                            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│  │ Application  │  │ Helm Charts  │  │ Terraform    │                 │
│  │   Code       │  │              │  │   Code       │                 │
│  └──────────────┘  └──────────────┘  └──────────────┘                 │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      GitHub Actions CI/CD Pipeline                      │
│  ┌──────────────────────────────────────────────────────┐             │
│  │  1. Build & Test Application                         │             │
│  │  2. Build Docker Images                              │             │
│  │  3. Push to AWS ECR                                  │             │
│  │  4. Update Helm Chart with New Image Tags            │             │
│  │  5. Commit Updated Helm Chart to Git                 │             │
│  └──────────────────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS Infrastructure                              │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │                    Terraform-Managed                          │      │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │      │
│  │  │     VPC      │  │  EKS Cluster │  │  ECR Registry│      │      │
│  │  │  (Subnets,   │  │  (Control    │  │              │      │      │
│  │  │   NAT, IGW)  │  │   Plane)     │  │              │      │      │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │      │
│  │                                                              │      │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │      │
│  │  │  Node Groups │  │  Load        │  │  IAM Roles   │      │      │
│  │  │  (Workers)   │  │  Balancer    │  │  & Policies  │      │      │
│  │  │              │  │  Controller  │  │              │      │      │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │      │
│  └──────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster (EKS)                           │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │                    ArgoCD Namespace                          │      │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │      │
│  │  │ ArgoCD       │  │ ArgoCD       │  │ ArgoCD       │      │      │
│  │  │ Server       │  │ Application  │  │ Repo Server  │      │      │
│  │  │ (UI/API)     │  │ Controller   │  │              │      │      │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │              Application Namespace(s)                         │      │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │      │
│  │  │ Microservice │  │ Microservice │  │ Microservice │      │      │
│  │  │  1 (API)     │  │  2 (Worker)  │  │  3 (Optional)│      │      │
│  │  │              │  │              │  │              │      │      │
│  │  │ Deployment   │  │ Deployment   │  │ Deployment   │      │      │
│  │  │ Service      │  │ Service      │  │ Service      │      │      │
│  │  │ ConfigMap    │  │ ConfigMap    │  │ ConfigMap    │      │      │
│  │  │ Secrets      │  │ Secrets      │  │ Secrets      │      │      │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │              Monitoring Namespace                             │      │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │      │
│  │  │ Prometheus   │  │ Grafana      │  │ Logging      │      │
│  │  │              │  │              │  │ (Loki/ELK)    │      │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │      │
│  └──────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      ArgoCD GitOps Flow                                 │
│                                                                          │
│  1. ArgoCD monitors Git repository for Helm chart changes               │
│  2. Detects changes in Helm chart values or templates                  │
│  3. Compares desired state (Git) with current state (Cluster)          │
│  4. Automatically syncs and deploys changes to EKS cluster             │
│  5. Monitors application health and sync status                         │
│  6. Provides UI for manual sync, rollback, and monitoring              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      External Access                                    │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│  │   Users      │  │   ArgoCD UI  │  │   Monitoring │                 │
│  │   (API)      │  │   (Port 8080)│  │   Dashboards │                 │
│  │              │  │              │  │              │                 │
│  │  Ingress     │  │  Ingress/    │  │  Ingress/    │                 │
│  │  Controller  │  │  Port Forward│  │  Port Forward│                 │
│  └──────────────┘  └──────────────┘  └──────────────┘                 │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Interactions

### 1. Development Flow
```
Developer → Code Commit → GitHub → GitHub Actions → Build & Push → ECR
```

### 2. Deployment Flow (GitHub Actions)
```
GitHub Actions → Update Helm Chart → Commit to Git → ArgoCD Detects → Deploy to EKS
```

### 3. GitOps Flow (ArgoCD)
```
Git Repository (Helm Charts) → ArgoCD → Kubernetes API → Deploy/Update Applications
```

### 4. Monitoring Flow
```
Applications → Metrics Exporters → Prometheus → Grafana → Dashboards
Applications → Logs → Logging Stack → Centralized Logs
```

## Data Flow

### Application Request Flow
```
User Request → AWS Load Balancer → Ingress Controller → Service → Pod → Application
```

### CI/CD Pipeline Flow
```
Code Change → GitHub Webhook → GitHub Actions → Build Image → Push to ECR → 
Update Helm Chart → Git Commit → ArgoCD Webhook → ArgoCD Sync → Deploy to EKS
```

### GitOps Sync Flow
```
Helm Chart Change in Git → ArgoCD Polls/Webhook → ArgoCD Compares State → 
Sync Required → ArgoCD Applies Changes → Application Updated
```

## Key Technologies & Their Roles

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Infrastructure** | Terraform | Define and provision AWS resources |
| **Container Registry** | AWS ECR | Store Docker images |
| **Orchestration** | Kubernetes (EKS) | Manage containerized applications |
| **Package Management** | Helm | Package and deploy Kubernetes applications |
| **CI/CD** | GitHub Actions | Automate build, test, and deployment |
| **GitOps** | ArgoCD | Continuous deployment and sync monitoring |
| **Monitoring** | Prometheus + Grafana | Metrics collection and visualization |
| **Logging** | CloudWatch/ELK/Loki | Centralized log aggregation |
| **Networking** | AWS VPC, ALB, Ingress | Network connectivity and load balancing |
| **Security** | IAM, RBAC, Secrets Manager | Access control and secrets management |

## Environment Strategy

### Development Environment
- Lower resource allocation
- Auto-deploy on every commit
- Basic monitoring

### Staging Environment
- Production-like configuration
- Manual approval for deployment
- Full monitoring and logging

### Production Environment
- High availability setup
- Multi-AZ deployment
- Full security hardening
- Comprehensive monitoring
- Disaster recovery plan

## High Availability Considerations

1. **EKS Cluster**: Multi-AZ control plane (managed by AWS)
2. **Node Groups**: Spread across multiple availability zones
3. **Application Pods**: Replicas across nodes and AZs
4. **Load Balancer**: Multi-AZ distribution
5. **ArgoCD**: High availability mode (multiple replicas)
6. **Monitoring**: Redundant Prometheus instances

## Security Layers

1. **Network**: VPC, Security Groups, Network Policies
2. **Access**: IAM, RBAC, Service Accounts
3. **Secrets**: AWS Secrets Manager, Kubernetes Secrets (encrypted)
4. **Container**: Image scanning, security policies
5. **Runtime**: Pod Security Policies, Network Policies
6. **Compliance**: Audit logging, compliance scanning

## Scalability Strategy

1. **Horizontal Pod Autoscaling (HPA)**: Based on CPU/memory metrics
2. **Cluster Autoscaling**: Automatically add/remove nodes
3. **Vertical Pod Autoscaling (VPA)**: Optimize resource requests
4. **Load Balancing**: Distribute traffic across pods
5. **CDN**: CloudFront for static content (if applicable)

