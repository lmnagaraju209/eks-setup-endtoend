# Phase 3: Production Hardening & Advanced Features

Complete guide for production-ready enhancements, CI/CD, monitoring, and optimizations.

## Overview

Phase 3 focuses on making the application production-ready with:
- Database integration
- Security hardening
- Monitoring and observability
- CI/CD automation
- Performance optimization

## Prerequisites

- ✅ Phase 1 completed (EKS cluster running)
- ✅ Phase 2 completed (Services deployed)
- GitHub/GitLab repository
- Domain name (optional, for SSL)

## Part A: Database Integration

### Option 1: Amazon RDS (Recommended)

**Step 1: Create RDS Instance**

Using AWS Console:
1. Go to RDS → Create database
2. Choose PostgreSQL or MySQL
3. Select instance class (db.t3.micro for testing)
4. Configure credentials
5. Set VPC to your EKS VPC
6. Create database

**Step 2: Update Backend Code**

Add dependencies to `services/backend/pom.xml`:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
</dependency>
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
</dependency>
```

**Step 3: Create Entity Class**

Update `Item.java`:
```java
@Entity
@Table(name = "items")
public class Item {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(nullable = false)
    private String name;
    
    private String description;
    // getters and setters
}
```

**Step 4: Create Repository**

Create `services/backend/src/main/java/com/example/backend/repository/ItemRepository.java`:
```java
package com.example.backend.repository;

import com.example.backend.model.Item;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface ItemRepository extends JpaRepository<Item, Long> {
}
```

**Step 5: Update Controller**

Update `ItemController.java` to use repository instead of in-memory map.

**Step 6: Configure Database Connection**

Update `application.properties`:
```properties
spring.datasource.url=jdbc:postgresql://${DB_HOST}:5432/${DB_NAME}
spring.datasource.username=${DB_USERNAME}
spring.datasource.password=${DB_PASSWORD}
spring.jpa.hibernate.ddl-auto=update
```

**Step 7: Update Kubernetes Deployment**

Add environment variables:
```yaml
env:
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: host
- name: DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password
```

## Part B: Secrets Management

### Using AWS Secrets Manager

**Step 1: Create Secret**
```bash
aws secretsmanager create-secret \
  --name backend-db-credentials \
  --secret-string '{"host":"your-rds-endpoint.region.rds.amazonaws.com","username":"admin","password":"secure-password","database":"mydb"}' \
  --region <region>
```

**Step 2: Create IAM Policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ],
    "Resource": "arn:aws:secretsmanager:<region>:<account>:secret:backend-db-credentials-*"
  }]
}
```

**Step 3: Configure IRSA**

Create service account with annotation:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-service-account
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account>:role/backend-secrets-role
```

**Step 4: Update Backend to Use Secrets**

Add AWS SDK dependency and load secrets at startup.

## Part C: SSL/TLS Certificates

### Using AWS Certificate Manager

**Step 1: Request Certificate**
```bash
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names "*.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1
```

**Step 2: Validate Certificate**
- Add DNS records as instructed
- Wait for validation (usually 5-10 minutes)

**Step 3: Update ALB Configuration**

Update Terraform to use certificate:
```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn    = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}
```

## Part D: Monitoring & Alerting

### CloudWatch Container Insights

**Step 1: Enable Container Insights**
```bash
aws eks update-addon \
  --cluster-name <cluster-name> \
  --addon-name amazon-cloudwatch-observability \
  --addon-version latest
```

**Step 2: Create CloudWatch Dashboard**

Create dashboard with:
- Pod CPU utilization
- Pod memory usage
- Request count
- Error rate
- Response time

**Step 3: Set Up Alarms**

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name backend-high-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ContainerInsights \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## Part E: CI/CD Pipeline

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push backend
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: backend
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./services/backend
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
      
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name <cluster-name> --region us-east-1
      
      - name: Deploy to EKS
        run: |
          kubectl set image deployment/backend backend=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          kubectl rollout status deployment/backend
```

## Part F: Log Aggregation

### Fluent Bit Setup

**Step 1: Create Fluent Bit ConfigMap**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: kube-system
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
    
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
    
    [OUTPUT]
        Name              cloudwatch_logs
        Match             *
        region            us-east-1
        log_group_name    /aws/eks/<cluster-name>/containers
        auto_create_group true
```

**Step 2: Deploy Fluent Bit**
```bash
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
```

## Part G: Performance Optimization

### Horizontal Pod Autoscaling

**Step 1: Install Metrics Server**
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

**Step 2: Create HPA**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Resource Optimization

**Step 1: Analyze Current Usage**
```bash
kubectl top pods
kubectl top nodes
```

**Step 2: Adjust Resource Requests/Limits**

Update deployment with actual requirements:
```yaml
resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 1000m
    memory: 512Mi
```

## Validation Checklist

- [ ] Database connected and migrations applied
- [ ] Secrets loaded from Secrets Manager
- [ ] HTTPS working on ALB
- [ ] CloudWatch dashboards showing metrics
- [ ] Alarms configured and tested
- [ ] CI/CD pipeline deploying automatically
- [ ] Logs visible in CloudWatch
- [ ] HPA scaling pods based on load
- [ ] Application performance improved

## Next Steps

After Phase 3:
- Multi-region deployment
- Disaster recovery setup
- Advanced security (WAF, DDoS protection)
- Service mesh implementation
- Cost optimization automation

