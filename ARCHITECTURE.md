# Architecture Overview

This document explains the end-to-end flow of the project in simple terms.

## End-to-End Flow (Diagram)

```text
Developer
  |
  | git push
  v
GitHub
  |
  | GitHub Actions (CI/CD)
  |  - tests
  |  - build Docker images
  |  - push to ECR
  v
Amazon ECR (container registry)
  |
  | images pulled by EKS
  v
Amazon EKS (Kubernetes)
  |
  | Helm deploys services
  |
  +--> Frontend Service (LoadBalancer) ---> Users (Browser)
  |
  +--> Backend Service (ClusterIP)
          |
          v
       PostgreSQL (database)
```

## What Each Part Does

- **Frontend**: Web UI exposed through a LoadBalancer.
- **Backend**: REST API used by the frontend.
- **Database**: PostgreSQL stores items data.
- **ECR**: Stores Docker images for backend and frontend.
- **EKS**: Runs the containers in Kubernetes.
- **Terraform**: Creates all AWS infrastructure.
- **Helm**: Installs the app into EKS.
- **GitHub Actions**: Automates build/test/push on every commit.

## Local Flow (Development)

```text
Developer -> docker-compose -> Frontend + Backend + Postgres (local)
```

This is the fastest way to test changes before pushing to GitHub.
