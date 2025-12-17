# Deployment Guide - Phase 2

Complete guide for deploying the application services to EKS.

## Prerequisites

- Phase 1 completed (EKS cluster running)
- kubectl configured: `aws eks update-kubeconfig --region <region> --name <cluster-name>`
- AWS ECR repository created
- Docker images built and pushed to ECR

## Step 1: Create ECR Repositories

```bash
aws ecr create-repository --repository-name backend --region <region>
aws ecr create-repository --repository-name frontend --region <region>
```

Get repository URLs:
```bash
aws ecr describe-repositories --region <region>
```

## Step 2: Build and Push Images

### Login to ECR
```bash
aws ecr get-login-password --region <region> | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

### Build Backend
```bash
cd services/backend
docker build -t <account-id>.dkr.ecr.<region>.amazonaws.com/backend:latest .
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/backend:latest
```

### Build Frontend
```bash
cd services/frontend
docker build -t <account-id>.dkr.ecr.<region>.amazonaws.com/frontend:latest .
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/frontend:latest
```

## Step 3: Create Kubernetes Manifests

Create `k8s/` directory and add deployment files.

### Backend Deployment (`k8s/backend-deployment.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: <account-id>.dkr.ecr.<region>.amazonaws.com/backend:latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "production"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

### Frontend Deployment (`k8s/frontend-deployment.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: <account-id>.dkr.ecr.<region>.amazonaws.com/frontend:latest
        ports:
        - containerPort: 3000
        env:
        - name: BACKEND_URL
          value: "http://backend-service:8080"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
```

### Services (`k8s/services.yaml`)
```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - port: 3000
    targetPort: 3000
  type: LoadBalancer
```

## Step 4: Deploy to EKS

```bash
kubectl apply -f k8s/
```

Check status:
```bash
kubectl get pods
kubectl get services
```

## Step 5: Access Application

Get LoadBalancer URL:
```bash
kubectl get service frontend-service
```

Open the EXTERNAL-IP in your browser.

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Image Pull Errors
Verify ECR permissions and image exists:
```bash
aws ecr describe-images --repository-name backend --region <region>
```

### Service Not Accessible
Check service endpoints:
```bash
kubectl get endpoints
kubectl describe service frontend-service
```

## Scaling

Scale backend:
```bash
kubectl scale deployment backend --replicas=3
```

## Updates

After pushing new images:
```bash
kubectl rollout restart deployment/backend
kubectl rollout restart deployment/frontend
```

## Cleanup

Remove deployments:
```bash
kubectl delete -f k8s/
```

