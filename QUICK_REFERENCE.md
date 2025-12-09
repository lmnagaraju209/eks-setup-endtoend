# EKS Setup Quick Reference

## Timeline

| Phase | Description | Time |
|-------|-------------|------|
| 1 | Infrastructure (Terraform) | 5-6 days |
| 2 | Application | 4-5 days |
| 3 | Helm Charts | 2.5-3 days |
| 4 | CI/CD | 3-4 days |
| 5 | ArgoCD | 2.5-3 days |
| 6 | Testing | 2-2.5 days |
| 7 | Monitoring | 2.5-3 days |
| 8 | Security | 2-2.5 days |
| 9 | Documentation | 1.5-2 days |
| 10 | Optimization | 1.5-2 days |
| **TOTAL** | | **4-5 weeks** |

## Checklist

### Phase 1: Infrastructure
- [ ] AWS account ready, Terraform installed
- [ ] VPC with multi-AZ subnets
- [ ] EKS cluster running
- [ ] Node groups configured
- [ ] Load Balancer Controller installed
- [ ] IRSA configured
- [ ] kubectl access working

### Phase 2: Application
- [ ] Services developed and tested locally
- [ ] Docker images built and pushed to ECR
- [ ] Health checks implemented
- [ ] Configuration externalized

### Phase 3: Helm Charts
- [ ] Chart structure created
- [ ] Deployment/Service manifests
- [ ] Ingress configured
- [ ] Values files per environment
- [ ] Chart tested (install/upgrade/rollback)

### Phase 4: CI/CD
- [ ] GitHub repo configured
- [ ] Build/test workflow
- [ ] Docker build/push workflow
- [ ] Helm chart update workflow
- [ ] Environment-specific workflows
- [ ] Notifications working

### Phase 5: ArgoCD
- [ ] ArgoCD installed
- [ ] Git repo connected
- [ ] Application CRDs created
- [ ] Sync policies configured
- [ ] UI accessible

### Phase 6: Testing
- [ ] End-to-end pipeline works
- [ ] ArgoCD syncs changes
- [ ] Services deployed and accessible
- [ ] Rollback tested

### Phase 7: Monitoring
- [ ] Prometheus/Grafana or CloudWatch
- [ ] Logging configured
- [ ] Alerts set up
- [ ] Application metrics exposed

### Phase 8: Security
- [ ] Network policies
- [ ] Secrets management
- [ ] RBAC configured
- [ ] Image scanning in CI/CD
- [ ] Audit logging enabled

### Phase 9: Documentation
- [ ] Architecture docs
- [ ] Runbooks
- [ ] Developer/operator guides

### Phase 10: Optimization
- [ ] Costs reviewed
- [ ] Performance tuned
- [ ] CI/CD optimized

## Tech Stack

**Infrastructure**: Terraform, AWS EKS, VPC, IAM, ECR  
**Application**: Docker, Kubernetes, Helm  
**CI/CD**: GitHub Actions, ArgoCD  
**Monitoring**: Prometheus, Grafana, CloudWatch  

## Critical Path

1. Infrastructure → Must be first
2. Application → Can start in parallel with infrastructure
3. Helm Charts → Needs application
4. CI/CD → Needs Helm charts + infrastructure
5. ArgoCD → Needs infrastructure + Helm charts
6. Everything else → Can be done in parallel or sequentially

## Parallel Work

- Infrastructure + Application development
- Helm charts + CI/CD setup
- Monitoring can start early (after infrastructure)
- Documentation is ongoing

## Common Issues

**AWS Limits**: Check service quotas before starting  
**IAM Permissions**: Get them right - saves time later  
**EKS Creation**: Takes 15-20 minutes, be patient  
**ArgoCD Sync**: First sync is slow, subsequent are faster  
**Network Policies**: Too restrictive breaks things - start permissive  

## Success Criteria

- [ ] Code commit triggers deployment
- [ ] ArgoCD auto-syncs changes
- [ ] Services are accessible and healthy
- [ ] Monitoring shows metrics
- [ ] Rollback works
- [ ] Team can operate it
