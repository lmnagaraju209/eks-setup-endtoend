# Detailed Project End-to-End Explanation (Line-by-Line)

This document explains the project files line by line (grouped by line ranges).
Generated/binary files are excluded.

## Exclusions (Generated / Binary)

- `udemy_course_slides.pptx` (binary)
- `services/frontend/package-lock.json` (generated)
- `services/frontend/coverage/**` (generated)
- `services/backend/target/**` (compiled)
- `terraform/terraform.tfstate*` (state files)
- `services/frontend/node_modules/**` (dependencies)

---

## Root Files

### `README.md`
- L1: Project title.
- L3-L6: Short project summary.
- L9-L15: Architecture diagram in text.
- L17-L22: Component list (backend, frontend, infra, CI/CD, GitOps).
- L24-L33: Local run instructions + ports.
- L34-L36: Link to `DEPLOYMENT_GUIDE.md`.
- L38-L56: Learning objectives (CI/CD, Kubernetes, GitOps).
- L58-L64: External documentation links.
- L66: End of file separator.

### `DEPLOYMENT_GUIDE.md`
- L1-L4: Guide title and summary.
- L6-L9: Prerequisites.
- L11-L31: S3 backend setup (first apply + migrate state).
- L33-L43: First infrastructure apply.
- L45-L53: `kubectl` configuration and verification.
- L55-L81: Build + push Docker images.
- L83-L97: Helm deployment.
- L99-L104: How to access the app.
- L106-L112: Basic troubleshooting commands.
- L114-L128: Optional add-ons on second apply.
- L130-L137: Safe re-apply/destroy guidance.
- L138-L144: Rollout updates.
- L146-L152: Cleanup steps.

### `ARCHITECTURE.md`
- L1-L3: Purpose of the document.
- L5-L33: End-to-end flow diagram.
- L35-L44: Component responsibilities.
- L46-L50: Local development flow.
- L52: Closing note.

### `ARCHITECTURE.md` (Flow Diagram Notes)
- L7-L33: CI/CD to EKS flow + frontend/backend/database path.

### `udemy_course_script.md`
- L1-L4: Script purpose and pacing.
- L6-L19: Course welcome + goals.
- L20-L36: What the app is + tools explained.
- L37-L57: Local run steps.
- L59-L93: Terraform apply + kubectl setup.
- L95-L123: Build and push images.
- L125-L146: Helm deploy + pod/service checks.
- L147-L159: Test steps.
- L161-L172: CI/CD overview.
- L174-L214: GitHub Actions setup from scratch.
- L216-L225: Wrap up.

---

## CI/CD

### `.github/workflows/deploy.yml`
- L1-L8: Workflow name and triggers (push/PR to `main`).
- L9-L18: Environment variables for AWS/ECR.
- L20-L28: Job definition and permissions for OIDC.
- L30-L49: Checkout and required variable validation.
- L50-L60: AWS credential setup using OIDC role.
- L61-L64: ECR login action.
- L65-L75: Java setup + backend tests.
- L76-L87: Node setup + frontend tests.
- L89-L115: Build, scan, tag, and push backend image.
- L116-L141: Build, scan, tag, and push frontend image.
- L143-L157: Update Helm values with new image tags.
- L158-L168: Commit and push updated Helm values.

---

## GitOps

### `argocd-application.yaml`
- L1-L13: Usage instructions and prerequisites.
- L14-L23: Application metadata and finalizers.
- L24-L36: Git source repo + chart path + values file.
- L37-L41: Destination cluster/namespace.
- L42-L58: Auto-sync and retry policy.
- L67-L96: Optional ApplicationSet template (commented).

---

## Local Development

### `services/docker-compose.yml`
- L1-L18: Postgres service (image, env, ports, healthcheck).
- L20-L41: Backend service (build, env, ports, healthcheck).
- L43-L59: Frontend service (build, env, ports, healthcheck).
- L60-L61: Persistent volume for Postgres.

---

## Backend (Spring Boot)

### `services/backend/Dockerfile`
- L1-L13: Build stage (Maven, copy source, package).
- L15-L39: Runtime stage (JRE, non-root user, healthcheck, entrypoint).

### `services/backend/pom.xml`
- L1-L23: Maven project + Java 17.
- L25-L82: Dependencies (Spring Boot, JPA, Postgres, AWS SDK, tests).
- L85-L125: Plugins (Java version enforcement, Spring Boot plugin).

### `services/backend/src/main/resources/application.properties`
- L1-L2: Server port and app name.
- L4-L6: Actuator endpoints and Prometheus.
- L8-L11: Logging and CORS.
- L12-L21: Database connection properties.
- L24-L26: Secrets Manager settings (region, secret name).

### `services/backend/src/main/java/.../BackendApplication.java`
- L1-L12: Spring Boot entrypoint.

### `services/backend/src/main/java/.../config/DatabaseConfig.java`
- L1-L14: Imports and config class setup.
- L15-L22: Conditional config + injected SecretsService.
- L24-L35: Read secrets if available; fallback to env vars.

### `services/backend/src/main/java/.../config/SecretsManagerConfig.java`
- L1-L14: Region injection and config.
- L16-L21: Build Secrets Manager client with default credentials.

### `services/backend/src/main/java/.../controller/HealthController.java`
- L1-L9: Imports.
- L10-L27: `/health` and `/ready` endpoints.

### `services/backend/src/main/java/.../controller/ItemController.java`
- L1-L15: REST controller setup.
- L17-L21: Repository injection.
- L23-L35: GET all + GET by id.
- L37-L41: POST create.
- L43-L51: PUT update.
- L53-L59: DELETE by id.

### `services/backend/src/main/java/.../model/Item.java`
- L1-L12: Entity annotations and Lombok.
- L13-L22: Fields (id, name, description).

### `services/backend/src/main/java/.../repository/ItemRepository.java`
- L1-L8: JPA repository interface for Item.

### `services/backend/src/main/java/.../service/SecretsService.java`
- L1-L14: Imports and fields.
- L16-L29: Constructor + secret name.
- L31-L61: Fetch secret from AWS and parse JSON.

### `services/backend/src/test/java/.../HealthControllerTest.java`
- L1-L38: Tests for `/health` and `/ready`.

### `services/backend/src/test/java/.../ItemControllerTest.java`
- L1-L49: Test setup + mock repository.
- L52-L70: GET all items.
- L72-L97: GET item (found/not found).
- L99-L116: POST create.
- L118-L152: PUT update (found/not found).
- L154-L179: DELETE (found/not found).

---

## Frontend (Node.js)

### `services/frontend/Dockerfile`
- L1-L12: Build stage (install dependencies).
- L14-L40: Runtime stage (copy files, non-root user, healthcheck).

### `services/frontend/server.js`
- L1-L8: Imports, app init, config.
- L10-L11: Prometheus metrics.
- L13-L15: Static + JSON middleware.
- L16-L33: `/api` proxy to backend with error handling.
- L35-L37: `/health` endpoint.
- L39-L46: `/metrics` endpoint.
- L48-L50: Serve SPA index.
- L52-L60: Export app + start server if run directly.

### `services/frontend/server.test.js`
- L1-L17: Setup mocks and load app.
- L28-L44: `/health` test.
- L46-L55: `/metrics` test.
- L57-L129: API proxy tests (GET, POST, error cases).

### `services/frontend/package.json`
- L1-L10: Package metadata and scripts.
- L11-L15: Runtime dependencies.
- L16-L19: Dev dependencies.
- L21-L23: Keywords/license.

### `services/frontend/jest.config.js`
- L1-L10: Jest configuration (env, coverage, test match).

### `services/frontend/public/index.html`
- L1-L133: HTML + styling for UI.
- L135-L157: Form layout and items list.
- L159-L261: Frontend JS (load, create, delete items).

---

## Helm Chart

### `helm/eks-setup-app/Chart.yaml`
- L1-L6: Chart metadata (name, version, type).

### `helm/eks-setup-app/values.yaml`
- L1-L15: Global/security defaults.
- L12-L35: External secrets config.
- L36-L85: Backend config (image, env, probes, resources).
- L86-L127: Frontend config (image, env, probes, resources).
- L128-L149: Optional ingress config.

### `helm/eks-setup-app/templates/_helpers.tpl`
- L1-L32: Name and label helper templates.
- L34-L39: Backend service account name helper.

### `helm/eks-setup-app/templates/backend-deployment.yaml`
- L1-L18: Deployment metadata.
- L19-L38: Pod spec, env vars, and external secrets.
- L56-L69: Probes and resources.

### `helm/eks-setup-app/templates/backend-service.yaml`
- L1-L17: Backend ClusterIP service.

### `helm/eks-setup-app/templates/frontend-deployment.yaml`
- L1-L27: Deployment metadata and service account.
- L28-L54: Container spec, env, probes, resources.

### `helm/eks-setup-app/templates/frontend-service.yaml`
- L1-L17: Frontend service definition.

### `helm/eks-setup-app/templates/backend-serviceaccount.yaml`
- L1-L12: Backend service account with optional annotations.

### `helm/eks-setup-app/templates/frontend-serviceaccount.yaml`
- L1-L12: Frontend service account with optional annotations.

### `helm/eks-setup-app/templates/external-secrets.yaml`
- L1-L12: SecretStore definition.
- L14-L34: ExternalSecret mapping.

### `helm/eks-setup-app/templates/networkpolicy.yaml`
- L1-L13: Default deny policy.
- L14-L35: Allow DNS.
- L36-L56: Allow frontend ingress.
- L57-L78: Allow frontend → backend.

---

## Terraform

### `terraform/versions.tf`
- L1-L25: Terraform and provider version pins.

### `terraform/variables.tf`
- L1-L130: AWS/VPC/node group variables.
- L132-L149: NAT gateway configuration.
- L152-L162: Default tags.
- L164-L214: Remote state variables.
- L217-L238: aws-auth + GitHub OIDC inputs.
- L244-L247: EKS audit logging toggle.

### `terraform/data.tf`
- L1-L2: AWS region and account data sources.

### `terraform/main.tf`
- L1-L37: AWS provider setup.
- L47-L65: Availability zones + VPC count.
- L82-L187: VPC selection logic + subnet selection.
- L189-L280: S3 + DynamoDB state storage.
- L282-L353: VPC module definition.
- L369-L465: EKS cluster + node group settings.
- L478-L518: Core add-ons (CNI, CoreDNS, kube-proxy, EBS CSI).
- L520-L580: IAM role for EBS CSI (IRSA).
- L594-L633: Kubernetes + Helm providers.
- L647-L703: aws-auth config map update logic.

### `terraform/ecr.tf`
- L1-L32: Backend/frontend ECR repos.
- L34-L69: Lifecycle policies.

### `terraform/github_oidc.tf`
- L1-L27: OIDC provider setup.
- L29-L59: Role trust policy.
- L61-L109: Permissions + role attachment.

### `terraform/iam-irsa.tf`
- L1-L46: Backend Secrets Manager role + policy.
- L48-L89: Fluent Bit log role + policy.

### `terraform/app_domain_ingress.tf`
- L1-L84: Route53 + ACM (optional).
- L86-L199: AWS LB Controller (optional).
- L201-L239: Self-signed TLS secret.
- L247-L303: Nginx ingress (optional).
- L305-L329: Shared annotations and dependencies.
- L331-L375: Root ingress (frontend).
- L377-L422: ArgoCD ingress.
- L424-L467: Grafana ingress.
- L469-L493: Route53 CNAME.

### `terraform/argocd.tf`
- L1-L107: ArgoCD Helm install.
- L109-L139: Admin secret fetch + password set.
- L141-L220: Optional ArgoCD Application manifest.

### `terraform/external_secrets.tf`
- L1-L21: Variables.
- L23-L92: IRSA role + policy.
- L94-L146: Service account + Helm release.

### `terraform/logging.tf`
- L1-L44: Variables + CloudWatch log group.
- L46-L104: Fluent Bit service account + Helm release.

### `terraform/monitoring.tf`
- L1-L52: Variables (Grafana + Alertmanager).
- L74-L96: Namespace + random password.
- L98-L200: Helm release for monitoring stack.

### `terraform/outputs.tf`
- L1-L199: Cluster, VPC, ECR, and ArgoCD outputs.
- L222-L251: Monitoring/logging/external-secrets outputs.

### `terraform/backend.tf.example`
- L1-L40: S3 backend template with placeholders.

### `terraform/terraform.tfvars`
- L1-L60: Example local settings for a single environment.

### `terraform/terraform.tfvars.example`
- L1-L106: Default example config for first apply.

### `terraform/terraform.tfvars.second`
- L1-L32: Optional add-ons for second apply.

### `terraform/rds.tf`
- L1-L64: Commented RDS template for future use.

### `terraform/SWITCH_AWS_ACCOUNT.md`
- L1-L38: Account-specific state overview.
- L39-L139: Step-by-step account switch flow.
- L144-L291: Examples + troubleshooting.

### `terraform/policies/aws-load-balancer-controller.json`
- L1-L138: AWS policy actions required by the load balancer controller.
