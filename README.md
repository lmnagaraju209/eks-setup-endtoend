# 🚀 End-to-End Application Deployment Project

**A complete, production-ready CI/CD pipeline demonstrating real-world application deployment on AWS EKS.**

This project demonstrates end-to-end deployment to AWS EKS with Terraform, Docker,
and Helm.
- Learning objectives and best practices

## 🏗️ Architecture

```
Developer → GitHub → CI/CD Pipeline → ECR → ArgoCD → EKS → Application Running
            ↓
    Tests → Build → Scan → Push → Deploy
```

**Components:**
- **Backend:** Java/Spring Boot REST API
- **Frontend:** Node.js/Express web UI
- **Infrastructure:** AWS EKS, ECR, IAM (via Terraform)
- **CI/CD:** GitHub Actions (tests, builds, security scans)
- **GitOps:** ArgoCD (automatic deployments)

## ⚡ Quick Start (local)

```bash
cd services
docker-compose up
```

- Frontend: http://localhost:3000
- Backend: http://localhost:8082

## 🚀 Deploy to AWS EKS

Follow **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** for the Terraform + Helm flow.

## 🎯 What You'll Learn

1. **CI/CD Concepts**
   - Automated testing in pipelines
   - Docker image building and registry management
   - Security scanning with Trivy
   - Automated deployments

2. **Kubernetes & Cloud**
   - Pods, Deployments, Services
   - Helm charts for templating
   - AWS EKS managed Kubernetes
   - Infrastructure as Code (Terraform)

3. **GitOps & Best Practices**
   - Declarative infrastructure
   - Git as source of truth
   - Automated synchronization
   - Production-ready workflows

## 📚 Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitHub Actions](https://docs.github.com/en/actions)

---

## ✅ End-to-End Understanding

Read **`Detailed_Project_endtoend_Explain.md`** for a complete, line-by-line
explanation of the project.
