# Bootstrap vs Cleanup: Comparison Guide

## Quick Comparison

| Aspect | `bootstrap.sh` | `cleanup.sh` |
|--------|---|---|
| **Purpose** | Set up cluster for deployment | Prepare cluster for destruction |
| **When Run** | After EKS created by Terraform | Before running `terraform destroy` |
| **Impact** | Creates resources | Removes resources |
| **Idempotent** | Yes (safe to re-run) | No (destructive) |
| **Default Mode** | Interactive with auto-install options | Interactive with confirmations |
| **Data Loss** | No | Yes - removes workloads |
| **Namespace Impact** | Creates namespaces | Deletes namespaces |
| **Example** | `./bootstrap.sh` | `./cleanup.sh --dry-run` |

## Detailed Comparison

### Bootstrap: Resource Creation

**Executed After:**
- Terraform creates EKS cluster in AWS
- `terraform apply` completes successfully
- kubeconfig is configured

**What It Creates:**

```
BOOTSTRAP SEQUENCE:
├─ 1. Validate & Connect
│  └─ Authenticate to AWS, kubectl access
├─ 2. Namespaces & Secrets
│  ├─ Create namespaces: mogambo, argocd
│  ├─ Create DB connection secrets
│  └─ Validate DSN formats
├─ 3. Storage (Optional)
│  ├─ Install EBS CSI addon
│  └─ Mark default StorageClass
├─ 4. Ingress (Optional)
│  ├─ Create IAM OIDC provider for IRSA
│  ├─ Create ALB controller IAM role
│  ├─ Tag subnets for ALB discovery
│  └─ Install AWS Load Balancer Controller
├─ 5. GitOps
│  ├─ Install ArgoCD (stable version)
│  ├─ Wait for ArgoCD services ready
│  └─ Deploy root-app.yaml
└─ 6. Verify
   └─ List created applications

CLUSTER STATE: Ready for application deployments
```

**Created Resources:**

```
AWS Resources:
- IAM OIDC Provider
- IAM Role (ALB controller)
- IAM Policies (ALB controller)

Kubernetes Resources:
- 2 Namespaces (mogambo, argocd)
- 2 Secrets (DB connection strings)
- ArgoCD installation (270+ resources)
- AWS Load Balancer Controller (Helm release)
- IngressClass (alb)

Deployed Applications (via ArgoCD):
- front-end service
- catalogue service + database
- carts service + database
- monitoring stack (Prometheus, Grafana, etc.)
```

### Cleanup: Resource Removal

**Executed Before:**
- Running `terraform destroy`
- Decommissioning the entire cluster

**What It Removes:**

```
CLEANUP SEQUENCE:
├─ 1. Connect & Validate
│  └─ Authenticate to AWS, kubectl access
├─ 2. ArgoCD Applications [DESTRUCTIVE]
│  ├─ Delete all Application resources
│  └─ Cascade: pods, deployments, services stop
├─ 3. Helm Releases [DESTRUCTIVE]
│  ├─ Uninstall aws-load-balancer-controller
│  ├─ Uninstall argocd (if installed via Helm)
│  └─ Uninstall application charts
├─ 4. AWS Load Balancers [DESTRUCTIVE]
│  ├─ Find ALBs by VPC association
│  ├─ Find NLBs by VPC association
│  └─ Delete all discovered load balancers
├─ 5. IAM Resources [DESTRUCTIVE]
│  ├─ Detach IAM policies from ALB role
│  ├─ Delete inline IAM policies
│  ├─ Delete ALB controller IAM role
│  └─ Delete managed IAM policy
├─ 6. OIDC Provider [OPTIONAL]
│  └─ Delete IAM OIDC provider (if --skip-oidc not used)
└─ 7. Kubernetes Namespaces [DESTRUCTIVE]
   ├─ Delete mogambo namespace (cascade)
   └─ Delete argocd namespace (cascade)

CLUSTER STATE: Ready for infrastructure destruction by Terraform
```

**Removed Resources:**

```
AWS Resources:
- Application Load Balancers (Ingress-created)
- Network Load Balancers (if any)
- IAM OIDC Provider (optional)
- IAM Role (ALB controller)
- IAM Policies (ALB controller)

Kubernetes Resources:
- ArgoCD applications (triggers deletion of services)
- Helm releases
- Namespaces (cascade deletes all content)
- Secrets
- ConfigMaps
- Deployments, StatefulSets
- Services, Ingresses
```

## Side-by-Side Workflow

### Complete Setup Flow

```
INITIAL STATE: Fresh AWS Account
│
├─ Run: terraform apply (in infra/terraform/environments/dev/)
│  └─ Creates: EKS cluster, VPC, RDS, S3, EC2, etc.
│  └─ State: Infrastructure provisioned, no workloads
│
├─ Run: ./scripts/bootstrap.sh
│  ├─ Prerequisites: EKS cluster, kubeconfig, AWS credentials
│  ├─ Creates: Namespaces, secrets, OIDC, ALB controller, ArgoCD
│  └─ State: GitOps ready, empty manifests
│
├─ Run: kubectl apply -f deploy/argocd/root-app.yaml
│  ├─ ArgoCD reconciles applications
│  ├─ Services deploy: front-end, catalogue, carts
│  ├─ Databases initialize: RDS MySQL, MongoDB
│  └─ State: Full platform running
│
├─ [APPLICATION RUNNING - TIME PASSES]
│ 
├─ Run: ./scripts/cleanup.sh
│  ├─ Removes: Applications, load balancers, IAM, namespaces
│  └─ State: Infrastructure empty, ready for destruction
│
└─ Run: terraform destroy (in infra/terraform/environments/dev/)
   ├─ Removes: All AWS resources (EKS, RDS, VPC, etc.)
   └─ State: Clean slate
```

## Configuration File Usage

Both scripts use `scripts/.env` for configuration:

```bash
# scripts/.env

# Cluster identification
export AWS_REGION="us-east-1"
export EKS_CLUSTER_NAME="mogambo-eks-cluster"

# Namespace configuration
export APP_NAMESPACE="mogambo"
export ARGOCD_NAMESPACE="argocd"

# Database secrets (bootstrap only)
export CATALOGUE_DB_DSN="user:pass@tcp(rds-endpoint:3306)/catalogue?allowNativePasswords=true"
export DATABASE_URL="mysql://user:pass@rds-endpoint:3306/catalogue"

# ALB controller configuration
export AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME="mogambo-aws-load-balancer-controller-role"
export AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-Mogambo"

# Installation flags (bootstrap only)
export AUTO_INSTALL_ARGOCD="true"
export AUTO_INSTALL_ALB_CONTROLLER="true"
export AUTO_INSTALL_EBS_CSI_ADDON="false"

# Cleanup preferences (cleanup only)
export SKIP_OIDC="false"  # Set to "true" to keep OIDC provider
```

## Mode Comparison

### Bootstrap Modes

**Interactive (default)**
```bash
./scripts/bootstrap.sh
# Automatically installs components, idempotent
```

**With custom env file**
```bash
./scripts/bootstrap.sh --env-file /path/to/custom.env
```

### Cleanup Modes

**Dry-Run (Recommended First Step)**
```bash
./scripts/cleanup.sh --dry-run
# Preview all actions without making changes
```

**Interactive (Default)**
```bash
./scripts/cleanup.sh
# Confirm each major operation before deletion
```

**Force Mode (CI/CD)**
```bash
./scripts/cleanup.sh --force --skip-oidc
# Skip confirmations, don't delete OIDC provider
```

## Error Handling

### Bootstrap Errors

| Issue | Solution |
|-------|----------|
| Kubeconfig not configured | Run: `aws eks update-kubeconfig --name CLUSTER_NAME --region REGION` |
| AWS credentials invalid | Check: `aws sts get-caller-identity` |
| Namespace already exists | Script is idempotent, safe to re-run |
| ArgoCD pod won't start | Check: `kubectl -n argocd describe pod <pod-name>` |
| ALB controller role exists | Script updates trust policy, re-runs safely |

### Cleanup Errors

| Issue | Solution |
|-------|----------|
| ALB won't delete | Check for target group attachments, delete manually if stuck |
| Namespace terminating | Remove finalizers: `kubectl patch ns mogambo -p '{"metadata":{"finalizers":[]}}'` |
| IAM role deletion fails | Ensure all policies detached: `aws iam list-attached-role-policies --role-name ROLE_NAME` |
| OIDC provider in use | Use `--skip-oidc` flag, delete manually after verifying no dependencies |

## Best Practices

### For Bootstrap

1. **One-time per cluster** - Run after each `terraform apply`
2. **Verify kube access first** - `kubectl get nodes` should work
3. **Validate secrets** - Ensure DB DSN is correct before running
4. **Wait for completion** - Script waits for ArgoCD to be ready (~2-3 minutes)
5. **Keep .env secure** - Contains database passwords

### For Cleanup

1. **Always dry-run first** - `./cleanup.sh --dry-run` before executing
2. **Backup important data** - Export RDS snapshots, S3 data first
3. **Confirm resource list** - Review what will be deleted
4. **Handle failures gracefully** - Script won't delete on confirmation=No
5. **Verify aftermath** - Run verification commands before terraform destroy
6. **Skip OIDC if unsure** - Use `--skip-oidc` if other services depend on it

## Common Scenarios

### Scenario 1: Full Development Cycle

```bash
# Day 1: Setup new environment
terraform apply
./scripts/bootstrap.sh

# Days 2-14: Development work
kubectl apply -f deploy/...
# Deploy, test, iterate

# Day 14: Teardown for cost savings
./scripts/cleanup.sh --dry-run
./scripts/cleanup.sh --force
terraform destroy -auto-approve
```

### Scenario 2: Troubleshooting ArgoCD

```bash
# Something wrong with ArgoCD, restart everything
./scripts/cleanup.sh --force  # Remove old ArgoCD
./scripts/bootstrap.sh        # Install fresh
```

### Scenario 3: Preserve Infrastructure, Redeploy Apps

```bash
# Keep AWS resources, just redeploy via GitOps
kubectl delete applications -n argocd --all
kubectl apply -f deploy/argocd/root-app.yaml
```

### Scenario 4: CI/CD Automation

```bash
# Automated daily teardown for cost optimization
#!/bin/bash
set -e
export FORCE_DELETE="true"
export SKIP_OIDC="true"
./scripts/cleanup.sh
terraform destroy -auto-approve
```

## Summary Table

| Activity | Script | Time | Destructive |
|----------|--------|------|---|
| Fresh cluster setup | `bootstrap.sh` | 2-5 min | No |
| Preview cleanup | `cleanup.sh --dry-run` | <1 min | No |
| Execute cleanup | `cleanup.sh` | 3-10 min | Yes |
| Force cleanup | `cleanup.sh --force` | <3 min | Yes |
| Infrastructure destroy | `terraform destroy` | 10-20 min | Yes |

## Additional Resources

- [Bootstrap Guide](./bootstrap-guide.md) - Detailed bootstrap documentation
- [Cleanup Guide](./cleanup-guide.md) - Detailed cleanup documentation
- [Terraform Documentation](../infra/README.md) - Infrastructure-as-Code reference
- [Troubleshooting](./troubleshooting.md) - Common issues and solutions
