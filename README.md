# EKS Setup - End to End

Complete setup for deploying applications on AWS EKS.

## Project Structure

- `terraform/` - EKS infrastructure setup (Phase 1)
- `services/` - Application services - Java backend and Node.js frontend (Phase 2)

## Documentation

- **[ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)** - System architecture and component overview
- **[PROJECT_PLAN.md](PROJECT_PLAN.md)** - Complete project plan with both phases
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Guide for deploying to EKS (Phase 2)
- **[CI_CD_GUIDE.md](CI_CD_GUIDE.md)** - CI/CD pipeline setup (Phase 4)
- **[PHASE4_PHASE5_WORKFLOW.md](PHASE4_PHASE5_WORKFLOW.md)** - Complete CI/CD + GitOps workflow (Phase 4 & 5)
- **[PHASE4_PHASE5_STATUS.md](PHASE4_PHASE5_STATUS.md)** - Implementation status for Phase 4 & 5
- **[argocd-application-setup.md](argocd-application-setup.md)** - ArgoCD Application setup guide (Phase 5)
- **[SECURITY_GUIDE.md](SECURITY_GUIDE.md)** - Phase 8 security hardening (NetworkPolicy, ESO, Trivy, audit logs)
- **[services/TEST_LOCALLY.md](services/TEST_LOCALLY.md)** - Local testing guide

## Quick Start

### Phase 1: Infrastructure Setup

```bash
cd terraform
terraform init
terraform apply
```

See [terraform/README.md](terraform/README.md) for details.

### Phase 2: Local Testing

```bash
cd services
docker-compose up
```

- Frontend: http://localhost:3000
- Backend: http://localhost:8082

See [services/TEST_LOCALLY.md](services/TEST_LOCALLY.md) for testing instructions.

### Phase 2: Deploy to EKS

After Phase 1 is complete, follow [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) to deploy services to your EKS cluster.

