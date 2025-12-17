# Architecture Overview

Comprehensive architecture documentation for the EKS setup and application deployment.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Infrastructure Components](#infrastructure-components)
3. [Application Components](#application-components)
4. [Network Architecture](#network-architecture)
5. [Data Flow](#data-flow)
6. [Security Architecture](#security-architecture)
7. [Scalability & High Availability](#scalability--high-availability)
8. [Cost Structure](#cost-structure)
9. [Technology Stack](#technology-stack)
10. [Deployment Architecture](#deployment-architecture)

## System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                               │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                     │ │
│  │                                                            │ │
│  │  ┌────────────────────┐      ┌────────────────────┐     │ │
│  │  │  Public Subnets    │      │  Private Subnets  │     │ │
│  │  │  (AZ-1, AZ-2)      │      │  (AZ-1, AZ-2)      │     │ │
│  │  │                    │      │                    │     │ │
│  │  │  ┌──────────────┐  │      │  ┌──────────────┐  │     │ │
│  │  │  │ Internet     │  │      │  │ NAT Gateway  │  │     │ │
│  │  │  │ Gateway      │  │      │  │              │  │     │ │
│  │  │  └──────────────┘  │      │  └──────────────┘  │     │ │
│  │  │                    │      │         │          │     │ │
│  │  │                    │      │         │          │     │ │
│  │  │                    │      │  ┌──────▼───────┐  │     │ │
│  │  │                    │      │  │ EKS Node     │  │     │ │
│  │  │                    │      │  │ Groups       │  │     │ │
│  │  │                    │      │  │              │  │     │ │
│  │  │                    │      │  │ ┌──────────┐│  │     │ │
│  │  │                    │      │  │ │ Pods     ││  │     │ │
│  │  │                    │      │  │ │          ││  │     │ │
│  │  │                    │      │  │ │ Backend  ││  │     │ │
│  │  │                    │      │  │ │ Frontend ││  │     │ │
│  │  │                    │      │  │ └──────────┘│  │     │ │
│  │  │                    │      │  └─────────────┘  │     │ │
│  │  └────────────────────┘      └──────────────────┘     │ │
│  │         │                            │                   │ │
│  │         └─────────── NAT ───────────┘                   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         EKS Control Plane (Managed by AWS)                │ │
│  │  - API Server (HTTPS endpoint)                            │ │
│  │  - etcd (cluster state)                                   │ │
│  │  - Scheduler                                              │ │
│  │  - Controller Manager                                    │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         Application Load Balancer (ALB)                  │ │
│  │  - Routes HTTP/HTTPS traffic                              │ │
│  │  - Health checks                                          │ │
│  │  - SSL/TLS termination                                   │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         Amazon ECR (Container Registry)                 │ │
│  │  - Private Docker image repositories                      │ │
│  │  - Image scanning                                         │ │
│  │  - Lifecycle policies                                     │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │         AWS IAM (Identity & Access Management)           │ │
│  │  - Cluster service role                                   │ │
│  │  - Node group role                                        │ │
│  │  - IRSA (IAM Roles for Service Accounts)                  │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Infrastructure Components

### VPC (Virtual Private Cloud)

**Purpose:** Isolated network environment for all resources.

**Configuration:**
- CIDR Block: `10.0.0.0/16` (65,536 IP addresses)
- DNS Resolution: Enabled
- DNS Hostnames: Enabled

**Subnet Architecture:**
- **Public Subnets:** 2-3 subnets across availability zones
  - CIDR: `10.0.1.0/24`, `10.0.2.0/24`, etc.
  - Route Table: Routes to Internet Gateway
  - Use Case: NAT Gateway, Load Balancers
  
- **Private Subnets:** 2-3 subnets across availability zones
  - CIDR: `10.0.10.0/24`, `10.0.11.0/24`, etc.
  - Route Table: Routes to NAT Gateway
  - Use Case: EKS nodes, application pods

**Network Components:**
- **Internet Gateway (IGW):** Provides internet access for public subnets
- **NAT Gateway:** Provides outbound internet access for private subnets
- **Route Tables:** Control traffic routing between subnets
- **Security Groups:** Firewall rules for network traffic

### EKS Cluster

**Purpose:** Managed Kubernetes control plane.

**Specifications:**
- Kubernetes Version: 1.28+ (configurable)
- Endpoint Access: Public and private (configurable)
- Logging: Control plane logs to CloudWatch
- Encryption: At rest and in transit

**Control Plane Components (Managed by AWS):**
- **API Server:** Handles all API requests
- **etcd:** Distributed key-value store for cluster state
- **Scheduler:** Assigns pods to nodes
- **Controller Manager:** Manages cluster controllers

**Access:**
- kubectl via AWS CLI authentication
- AWS Console integration
- API endpoint (HTTPS)

### Node Groups

**Purpose:** EC2 instances that run Kubernetes pods.

**Configuration:**
- Instance Type: t3.small (2 vCPU, 2 GB RAM) - configurable
- Instance Count: 2 nodes minimum (for high availability)
- AMI: Amazon EKS Optimized AMI
- Storage: 20 GB EBS volume per node
- Auto Scaling: Enabled (min: 2, max: 10)

**Node Components:**
- **kubelet:** Kubernetes agent on each node
- **kube-proxy:** Network proxy for service routing
- **Container Runtime:** Docker or containerd
- **VPC CNI Plugin:** AWS networking plugin

**Placement:**
- Deployed in private subnets
- Spread across multiple availability zones
- Auto-recovery enabled

### EKS Add-ons

**VPC CNI (Container Network Interface)**
- Version: Latest compatible with cluster version
- Purpose: Provides pod networking using VPC IP addresses
- Features: ENI trunking, security group assignment per pod

**CoreDNS**
- Version: Latest compatible
- Purpose: DNS service discovery for pods
- Configuration: Cluster DNS resolver

**kube-proxy**
- Version: Latest compatible
- Purpose: Network proxy for Kubernetes services
- Mode: IPVS (high performance)

**EBS CSI Driver**
- Version: Latest compatible
- Purpose: Dynamic provisioning of EBS volumes
- Use Case: Persistent volumes for stateful applications

### IAM Roles and Policies

**Cluster Service Role**
- Permissions: EKS cluster management
- Policies: `AmazonEKSClusterPolicy`
- Use: Control plane operations

**Node Group Role**
- Permissions: EC2 instance operations
- Policies:
  - `AmazonEKSWorkerNodePolicy`
  - `AmazonEKS_CNI_Policy`
  - `AmazonEC2ContainerRegistryReadOnly`
  - `AmazonEBSCSIDriverPolicy`
- Use: Node operations, image pulling, volume management

**IRSA (IAM Roles for Service Accounts)**
- Purpose: Grant AWS permissions to specific pods
- Use Case: Access S3, DynamoDB, Secrets Manager from pods
- Implementation: OIDC provider + service account annotations

## Application Components

### Backend Service (Java Spring Boot)

**Technology Stack:**
- Framework: Spring Boot 3.2.0
- Java Version: 17
- Build Tool: Maven
- Container: OpenJDK 17 Alpine

**Architecture:**
- **REST API:** Stateless microservice
- **Port:** 8080 (internal)
- **Data Store:** In-memory (ConcurrentHashMap)
  - *Note: Replace with database in production*

**Endpoints:**
```
GET    /health              - Liveness probe
GET    /ready               - Readiness probe
GET    /api/v1/items        - List all items
GET    /api/v1/items/{id}   - Get item by ID
POST   /api/v1/items        - Create item
PUT    /api/v1/items/{id}   - Update item
DELETE /api/v1/items/{id}   - Delete item
```

**Features:**
- Health check endpoints for Kubernetes probes
- CORS enabled for frontend access
- JSON request/response
- UUID-based item IDs

**Resource Requirements:**
- CPU: 100m (request), 500m (limit)
- Memory: 256Mi (request), 512Mi (limit)

### Frontend Service (Node.js Express)

**Technology Stack:**
- Runtime: Node.js 20
- Framework: Express.js
- Container: Node.js 20 Alpine

**Architecture:**
- **Web Server:** Express.js serving static files
- **Port:** 3000 (internal)
- **API Proxy:** Forwards `/api/*` requests to backend
- **SPA Routing:** Serves index.html for all routes

**Features:**
- Static file serving (HTML, CSS, JavaScript)
- API request proxying
- Health check endpoint
- Environment-based backend URL configuration

**Resource Requirements:**
- CPU: 100m (request), 500m (limit)
- Memory: 128Mi (request), 256Mi (limit)

## Network Architecture

### Traffic Flow

**Inbound Traffic (User → Application):**
```
Internet
  ↓
Application Load Balancer (ALB)
  - Listener: Port 80/443
  - Target Group: Frontend Service (port 3000)
  - Health Check: /health
  ↓
Kubernetes Service (LoadBalancer type)
  - Selector: app=frontend
  - Port: 3000
  ↓
Frontend Pods (Node.js)
  - Multiple replicas for load distribution
  ↓
Internal API Call
  ↓
Kubernetes Service (ClusterIP type)
  - Selector: app=backend
  - Port: 8080
  ↓
Backend Pods (Java Spring Boot)
```

**Outbound Traffic (Pods → Internet):**
```
Pod (Private Subnet)
  ↓
NAT Gateway (Public Subnet)
  ↓
Internet Gateway
  ↓
Internet
```

**Internal Pod-to-Pod Communication:**
```
Pod A (10.0.10.5)
  ↓
VPC CNI (assigns VPC IP)
  ↓
VPC Routing
  ↓
Pod B (10.0.10.6)
```

### Service Discovery

**Kubernetes DNS (CoreDNS):**
- Service name resolution: `backend-service.default.svc.cluster.local`
- Short name: `backend-service`
- Namespace: `default` (or custom namespace)

**DNS Resolution Flow:**
```
Pod makes DNS query
  ↓
CoreDNS Pod (kube-system namespace)
  ↓
Service IP resolution
  ↓
kube-proxy routing
  ↓
Target Pod
```

## Data Flow

### Request Processing Flow

```
1. User Request
   └─> Browser sends HTTP request to ALB

2. Load Balancing
   └─> ALB selects healthy frontend pod
   └─> Routes to pod IP (10.0.10.x)

3. Frontend Processing
   └─> Express server receives request
   └─> If /api/*: Proxy to backend
   └─> If /*: Serve static files or index.html

4. Backend API Call (if needed)
   └─> Frontend pod → backend-service:8080
   └─> DNS resolution via CoreDNS
   └─> kube-proxy routes to backend pod

5. Backend Processing
   └─> Spring Boot controller handles request
   └─> Business logic execution
   └─> In-memory data store access
   └─> JSON response generation

6. Response Path
   └─> Backend → Frontend → ALB → User
```

### Deployment Flow

```
1. Code Commit
   └─> Developer commits to Git repository

2. Image Build
   └─> Docker build creates image
   └─> Image tagged with version

3. Image Push
   └─> Push to Amazon ECR
   └─> Image stored in private repository

4. Manifest Update
   └─> Update Kubernetes deployment YAML
   └─> Change image tag to new version

5. Deployment
   └─> kubectl apply -f deployment.yaml
   └─> Kubernetes scheduler assigns pods

6. Rolling Update
   └─> New pods created with new image
   └─> Old pods terminated after new ones healthy
   └─> Zero-downtime deployment

7. Verification
   └─> Health checks confirm pods ready
   └─> Traffic routed to new pods
```

## Security Architecture

### Network Security

**Security Groups:**
- **ALB Security Group:**
  - Inbound: 80, 443 from 0.0.0.0/0
  - Outbound: All traffic

- **Node Security Group:**
  - Inbound: All traffic from ALB SG, Node SG
  - Outbound: All traffic (for NAT Gateway)

- **Pod-to-Pod:** Communication within VPC only

**Network Policies (Optional):**
- Restrict pod-to-pod communication
- Define allowed ingress/egress rules
- Namespace-level isolation

### Access Control

**AWS IAM:**
- Least privilege principle
- Separate roles for cluster, nodes, pods
- IRSA for pod-level permissions

**Kubernetes RBAC:**
- Service accounts for pods
- Role-based access control
- Cluster roles and bindings

**Container Security:**
- Non-root user in containers
- Read-only root filesystem (where possible)
- Minimal base images (Alpine Linux)

### Secrets Management

**Kubernetes Secrets:**
- Base64 encoded (not encrypted)
- Stored in etcd
- Mounted as volumes or environment variables

**AWS Secrets Manager (Recommended):**
- Encrypted at rest
- Automatic rotation
- Access via IRSA
- Audit logging

### Image Security

**ECR Features:**
- Image scanning for vulnerabilities
- Lifecycle policies for cleanup
- Private repositories
- Access via IAM

## Scalability & High Availability

### Horizontal Pod Autoscaling (HPA)

**Configuration:**
- Metric: CPU utilization
- Target: 70% average CPU
- Min Replicas: 2
- Max Replicas: 10

**Scaling Behavior:**
- Scale up when CPU > 70% for 2 minutes
- Scale down when CPU < 50% for 5 minutes
- Cooldown period between scaling actions

### Cluster Autoscaling

**Node Group Autoscaling:**
- Min Nodes: 2
- Max Nodes: 10
- Scale up when pods can't be scheduled
- Scale down when nodes underutilized

### High Availability

**Multi-AZ Deployment:**
- Nodes spread across 2-3 availability zones
- Pods distributed across zones
- Automatic failover

**Pod Disruption Budget:**
- Minimum available pods: 1
- Ensures service availability during updates

**Health Checks:**
- Liveness probe: Restart unhealthy pods
- Readiness probe: Remove from load balancer
- Startup probe: Wait for slow-starting pods

## Cost Structure

### Monthly Costs (Estimated)

**Fixed Costs:**
- EKS Control Plane: $73/month
- NAT Gateway: $32.40/month (0.045/hour)
- NAT Gateway Data Processing: ~$0.045/GB

**Variable Costs:**
- EC2 Instances (2x t3.small): ~$30/month
  - t3.small: $0.0208/hour × 730 hours × 2 = ~$30.37
- EBS Volumes (20 GB × 2): ~$2/month
- Data Transfer: ~$10-20/month (varies)
- ECR Storage: ~$1-5/month (varies)

**Total Estimated:** $155-175/month

### Cost Optimization Strategies

1. **Use Spot Instances:** 50-90% savings (non-production)
2. **Right-size Instances:** Monitor and adjust
3. **Reserved Instances:** 30-50% savings for 1-3 year commitments
4. **Single NAT Gateway:** Use one instead of per-AZ
5. **Fargate:** Pay per pod (no node management)
6. **Auto-scaling:** Scale down during low usage

## Technology Stack

### Infrastructure
- **Terraform:** Infrastructure as Code
- **AWS EKS:** Managed Kubernetes
- **AWS VPC:** Network isolation
- **Amazon ECR:** Container registry

### Container Runtime
- **Docker:** Container engine
- **containerd:** Alternative runtime

### Orchestration
- **Kubernetes:** Container orchestration
- **kubectl:** CLI tool

### Application Backend
- **Java 17:** Programming language
- **Spring Boot 3.2.0:** Framework
- **Maven:** Build tool

### Application Frontend
- **Node.js 20:** Runtime
- **Express.js:** Web framework
- **HTML/CSS/JavaScript:** Frontend technologies

### Monitoring (Future)
- **Prometheus:** Metrics collection
- **Grafana:** Visualization
- **CloudWatch:** AWS monitoring

## Deployment Architecture

### Development Environment
- Local Docker Compose
- Direct port mapping
- Hot reload support

### Staging Environment
- EKS cluster (shared or separate)
- Automated deployments
- Integration testing

### Production Environment
- Dedicated EKS cluster
- Blue-green deployments
- Canary releases
- Monitoring and alerting

### CI/CD Pipeline (Future)
```
Git Push
  ↓
GitHub Actions / GitLab CI
  ↓
Build Docker Images
  ↓
Push to ECR
  ↓
Update Kubernetes Manifests
  ↓
Deploy to EKS
  ↓
Run Tests
  ↓
Monitor Deployment
```

## Future Enhancements

### Short Term
- Database integration (RDS PostgreSQL/MySQL)
- Redis caching layer
- SSL/TLS certificates (ACM)
- Basic monitoring (CloudWatch)

### Medium Term
- CI/CD pipeline setup
- Multi-environment (dev/staging/prod)
- Service mesh (Istio/Linkerd)
- Advanced monitoring (Prometheus/Grafana)

### Long Term
- Multi-region deployment
- Disaster recovery setup
- Advanced security (WAF, DDoS protection)
- Cost optimization and automation
