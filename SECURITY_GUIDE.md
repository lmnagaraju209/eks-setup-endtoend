# Phase 8: Security

This repo implements Phase 8 items using Terraform + Helm.

## Network Security (NetworkPolicies)

Helm chart: `helm/eks-setup-app`

- Enable with:
  - `networkPolicy.enabled=true`
- It applies:
  - default deny (ingress+egress)
  - allow DNS egress to `kube-system`
  - allow inbound to frontend on its service port
  - allow frontend -> backend on backend service port

Tighten further by restricting frontend ingress to your ingress controller namespace/CIDRs.

## Secrets Management (AWS Secrets Manager + External Secrets Operator)

Terraform installs ESO by default (`enable_external_secrets = true`).

### 1) Create a secret in AWS Secrets Manager

Store JSON like:

```json
{ "DB_URL": "jdbc:postgresql://<host>:5432/itemsdb", "DB_USERNAME": "postgres", "DB_PASSWORD": "..." }
```

### 2) Enable ExternalSecret in Helm

Set in `helm/eks-setup-app/values.yaml` (or an env override):

- `externalSecrets.enabled=true`
- `externalSecrets.backend.awsSecretName=backend-db-credentials`

This creates:
- `SecretStore` (AWS Secrets Manager)
- `ExternalSecret` that syncs into K8s Secret `backend-db-env`

Backend Deployment will read `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` from that secret.

## RBAC

- Backend and frontend run under dedicated ServiceAccounts.
- Default token mounting is disabled (`automountServiceAccountToken: false`).

If you need K8s API access later (e.g., leaders, controllers), add minimal Role/RoleBinding then.

## Container Security (Trivy)

GitHub Actions workflow scans backend/frontend images with Trivy and fails on **HIGH/CRITICAL**.

## Audit & Compliance (EKS audit logs)

Terraform enables EKS control-plane logs (including `audit`) when:

- `enable_eks_control_plane_audit_logs = true`

After apply, view in CloudWatch under the EKS control-plane log group for your cluster.


