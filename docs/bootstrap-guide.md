# Bootstrap Guide: Mogambo Platform Setup

## Overview

The `bootstrap.sh` script prepares a fresh EKS cluster for the Mogambo microservices platform deployment using ArgoCD GitOps approach.

## Prerequisites

### Local Requirements

- `kubectl`: Kubernetes CLI configured
- `helm`: Helm 3.0+
- `aws`: AWS CLI v2
- `curl`: For downloading manifests
- `openssl`: For certificate operations

### AWS Account Requirements

- AWS credentials configured (`~/.aws/credentials` or environment variables)
- Sufficient IAM permissions (EC2, ECS, VPC, IAM, RDS access)
- EKS cluster already created (via Terraform)
- kubeconfig updated for the cluster

### Cluster Requirements

- EKS cluster version 1.24+
- At least 2 node groups with sufficient capacity (3-6 nodes recommended)
- Network access from local machine to EKS API
- OIDC provider support enabled (default in EKS)

## Configuration

### Environment File (`.env`)

Before running bootstrap, create or update `scripts/.env`:

```bash
# AWS Configuration
export AWS_REGION="us-east-1"
export EKS_CLUSTER_NAME="mogambo-eks-cluster"

# Namespace Configuration
export APP_NAMESPACE="mogambo"
export ARGOCD_NAMESPACE="argocd"

# Database Configuration (REQUIRED)
export CATALOGUE_DB_DSN="user:password@tcp(rds-endpoint:3306)/catalogue?allowNativePasswords=true"
export DATABASE_URL="mysql://user:password@rds-endpoint:3306/catalogue"

# ArgoCD Configuration
export ARGOCD_ROOT_APP_MANIFEST="deploy/argocd/root-app.yaml"
export ARGOCD_INSTALL_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# Installation Flags
export AUTO_INSTALL_ARGOCD="true"
export AUTO_INSTALL_ALB_CONTROLLER="true"
export AUTO_INSTALL_EBS_CSI_ADDON="false"

# ALB Controller IAM Configuration
export AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME="mogambo-aws-load-balancer-controller-role"
export AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-Mogambo"
```

### Step-by-Step Configuration

#### 1. Set AWS Credentials

```bash
# Option A: AWS CLI v2 Profile
export AWS_PROFILE="default"
aws sts get-caller-identity

# Option B: Environment Variables
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."  # if using temporary credentials
```

#### 2. Get EKS Cluster Name

```bash
# From Terraform output
cd infra/terraform/environments/dev
terraform output -raw eks_cluster_name

# Or list clusters
aws eks list-clusters --region us-east-1 --output text
```

#### 3. Update kubeconfig

```bash
aws eks update-kubeconfig \
  --name mogambo-eks-cluster \
  --region us-east-1

# Verify access
kubectl get nodes
```

#### 4. Find RDS Endpoint

```bash
# Find RDS instance
aws rds describe-db-instances \
  --region us-east-1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Example output: mogambo-mysql.czxyz.us-east-1.rds.amazonaws.com
```

#### 5. Create Database Credentials

```bash
# If database already exists, get credentials from AWS Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id rds-password \
  --region us-east-1 \
  --query SecretString \
  --output text

# Or use credentials from Terraform
cd infra/terraform/environments/dev
terraform output rds_master_username
terraform output rds_master_password
```

#### 6. Prepare .env File

```bash
# Create scripts/.env
cat > scripts/.env <<'EOF'
export AWS_REGION="us-east-1"
export EKS_CLUSTER_NAME="mogambo-eks-cluster"
export APP_NAMESPACE="mogambo"
export ARGOCD_NAMESPACE="argocd"

# Warning: Replace with actual values!
export CATALOGUE_DB_DSN="mogambo:SecurePassword123@tcp(mogambo-mysql.czxyz.us-east-1.rds.amazonaws.com:3306)/catalogue?allowNativePasswords=true"
export DATABASE_URL="mysql://mogambo:SecurePassword123@mogambo-mysql.czxyz.us-east-1.rds.amazonaws.com:3306/catalogue"

export ARGOCD_ROOT_APP_MANIFEST="deploy/argocd/root-app.yaml"
export AUTO_INSTALL_ARGOCD="true"
export AUTO_INSTALL_ALB_CONTROLLER="true"
export AUTO_INSTALL_EBS_CSI_ADDON="false"
EOF

# Secure the file
chmod 600 scripts/.env
```

## Running Bootstrap

### Quick Start

```bash
# 1. Navigate to repository
cd projects/mogambo-microservices-platform

# 2. Create/update .env
# See Configuration section above

# 3. Run bootstrap
./scripts/bootstrap.sh
```

### Full Execution Flow

```
Step 1: Validate Local Prerequisites
✓ Checks: kubectl, helm, aws, curl, openssl available
✓ Validates: .env file loaded, cluster name set

Step 2: Authenticate AWS and Configure kubectl
✓ Verifies: AWS credentials valid
✓ Updates: kubeconfig for cluster
✓ Tests: Kubernetes cluster access

Step 3: Ensure Namespaces and Required Secrets
✓ Creates: namespaces (mogambo, argocd)
✓ Creates: Database connection secrets
✓ Validates: Secret formats correct

Step 4: Storage Prerequisites
✓ Creates/verifies: StorageClass (gp2 as default)
✓ Optional: Installs EBS CSI addon

Step 5: Ingress Prerequisites
✓ Creates: IAM OIDC provider for IRSA
✓ Creates: ALB controller IAM role and policies
✓ Tests: ALB controller can assume role
✓ Tags: VPC subnets for ALB discovery
✓ Optional: Installs AWS Load Balancer Controller

Step 6: Install/Validate ArgoCD
✓ Downloads: ArgoCD stable manifest
✓ Applies: ArgoCD installation
✓ Waits: ArgoCD pods become ready

Step 7: Apply ArgoCD Root App
✓ Applies: root-app.yaml manifest
✓ Waits: Application controller recognizes apps
✓ Status: Applications in initial sync state

Step 8: Bootstrap Complete
✓ Summary displayed with next steps
```

### Usage Options

```bash
# Default: uses scripts/.env
./scripts/bootstrap.sh

# Custom env file
./scripts/bootstrap.sh --env-file /path/to/custom.env

# Show help
./scripts/bootstrap.sh --help
```

## Monitoring Bootstrap Progress

### Real-Time Monitoring

```bash
# In a separate terminal, watch pod creation
kubectl get pods -n mogambo -w
kubectl get pods -n argocd -w
kubectl get pods -n kube-system -w

# Check application status
watch kubectl -n argocd get applications

# View ArgoCD server logs
kubectl -n argocd logs -f deployment/argocd-server

# View application controller logs
kubectl -n argocd logs -f statefulset/argocd-application-controller
```

### Verify Each Stage

```bash
# Step 1-2: AWS Access
aws sts get-caller-identity
kubectl get nodes

# Step 3: Namespaces & Secrets
kubectl get namespaces
kubectl -n mogambo get secrets
kubectl -n mogambo describe secret catalogue-db-connection-secret

# Step 4: Storage
kubectl get storageclass
kubectl get pv

# Step 5: ALB Controller
kubectl -n kube-system get deployment aws-load-balancer-controller
kubectl -n kube-system logs deployment/aws-load-balancer-controller --tail=20

# Step 6: ArgoCD
kubectl -n argocd get pods
kubectl -n argocd port-forward svc/argocd-server 8080:443
# Access: https://localhost:8080 (self-signed cert warning OK)

# Step 7: Applications
kubectl -n argocd get applications
kubectl -n argocd describe application front-end
kubectl -n mogambo get pods
```

## Verification Checklist

After bootstrap completes:

- [ ] **Kubernetes Access**
  ```bash
  kubectl get nodes  # Should show node group
  kubectl get namespaces | grep mogambo  # Should exist
  ```

- [ ] **Namespaces**
  ```bash
  kubectl get nsreate mogambo argocd  # Both should exist
  ```

- [ ] **Secrets**
  ```bash
  kubectl -n mogambo get secret catalogue-db-connection-secret
  kubectl -n mogambo get secret catalogue-db-migrate-secret
  ```

- [ ] **ArgoCD Installation**
  ```bash
  kubectl -n argocd get deployment argocd-server
  kubectl -n argocd get statefulset argocd-application-controller
  kubectl -n argocd get pods | grep Running  # All should be Running
  ```

- [ ] **ArgoCD Applications**
  ```bash
  kubectl -n argocd get applications
  # Should show: front-end, catalogue, catalogue-db, carts, carts-db (at least)
  ```

- [ ] **ALB Controller** (if AUTO_INSTALL_ALB_CONTROLLER=true)
  ```bash
  kubectl -n kube-system get deployment aws-load-balancer-controller
  kubectl -n kube-system get sa aws-load-balancer-controller
  ```

- [ ] **OIDC Provider**
  ```bash
  aws iam list-open-id-connect-providers | grep oidc.eks
  ```

- [ ] **IAM Role**
  ```bash
  aws iam get-role --role-name mogambo-aws-load-balancer-controller-role
  ```

## Troubleshooting

### Issue: `command -v kubectl: not found`

**Message**: Missing required command: kubectl

**Solution**:
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

### Issue: `Cannot access Kubernetes cluster`

**Message**: The connection to EKS cluster failed

**Solution**:
```bash
# 1. Update kubeconfig
aws eks update-kubeconfig \
  --name mogambo-eks-cluster \
  --region us-east-1

# 2. Verify AWS credentials
aws sts get-caller-identity

# 3. Check cluster exists
aws eks describe-cluster \
  --name mogambo-eks-cluster \
  --region us-east-1

# 4. Test direct access
kubectl get nodes
```

### Issue: `RDS endpoint placeholder is still present`

**Message**: REPLACE_RDS_ENDPOINT placeholder in .env

**Solution**:
```bash
# 1. Find real RDS endpoint
aws rds describe-db-instances \
  --region us-east-1 \
  --query 'DBInstances[0].Endpoint.Address'

# 2. Update scripts/.env with actual endpoint
export CATALOGUE_DB_DSN="user:pass@tcp(ACTUAL-ENDPOINT:3306)/catalogue?allowNativePasswords=true"
export DATABASE_URL="mysql://user:pass@ACTUAL-ENDPOINT:3306/catalogue"

# 3. Verify no placeholders remain
grep -E 'REPLACE_|ACCOUNT_ID' scripts/.env || echo "OK"
```

### Issue: `DATABASE_URL format invalid`

**Message**: Incorrect DSN format

**Solution**:
```bash
# Catalogue expects format: user:password@tcp(host:port)/database
# Example that WORKS:
export CATALOGUE_DB_DSN="mogambo:pass123@tcp(rds.example.com:3306)/catalogue?allowNativePasswords=true"

# Example that FAILS:
export CATALOGUE_DB_DSN="mysql://mogambo:pass123@rds.example.com:3306/catalogue"  # Wrong!

# Correct format:
export DATABASE_URL="mysql://mogambo:pass123@rds.example.com:3306/catalogue"
```

### Issue: ArgoCD pod stuck in `Pending`

**Message**: argocd-server, argocd-repo-server pods not starting

**Solution**:
```bash
# 1. Check events
kubectl -n argocd describe pod argocd-server-XXX

# 2. Common causes:
# - Insufficient node resources: kubectl top nodes
# - PVC not bound: kubectl get pvc -n argocd
# - Node selector mismatch: kubectl get nodes --show-labels

# 3. Check node resources
kubectl top nodes
kubectl describe nodes

# 4. Restart if hung
kubectl -n argocd delete pod -l app.kubernetes.io/name=argocd-server
```

### Issue: ALB Controller RBAC error

**Message**: ALB controller cannot authenticate (403 Forbidden)

**Solution**:
```bash
# 1. Verify IAM role created
aws iam get-role --role-name mogambo-aws-load-balancer-controller-role

# 2. Check service account annotation
kubectl -n kube-system get sa aws-load-balancer-controller -o yaml | grep role-arn

# 3. Verify trust relationship
aws iam get-role --role-name mogambo-aws-load-balancer-controller-role \
  --query 'Role.AssumeRolePolicyDocument'

# 4. Restart controller
kubectl -n kube-system rollout restart deployment/aws-load-balancer-controller
```

### Issue: OIDC Provider creation fails

**Message**: Certificate operations failed for OIDC provider

**Solution**:
```bash
# 1. Check OpenSSL available
openssl version

# 2. Test TLS connection to EKS OIDC endpoint
OIDC_ISSUER=$(aws eks describe-cluster \
  --name mogambo-eks-cluster \
  --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' \
  --output text)

echo | openssl s_client -servername ${OIDC_ISSUER#https://} \
  -showcerts -connect ${OIDC_ISSUER#https://}:443 2>/dev/null | \
  openssl x509 -fingerprint -sha1 -noout

# 3. If network blocked, check egress rules
# Bootstrap needs outbound HTTPS (port 443)
```

## Advanced Configuration

### Custom ArgoCD Version

```bash
# Override manifest URL for different ArgoCD version
export ARGOCD_INSTALL_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/v2.8.3/manifests/install.yaml"

./scripts/bootstrap.sh
```

### Skip EBS CSI Installation

```bash
# If using different storage provider
export AUTO_INSTALL_EBS_CSI_ADDON="false"
./scripts/bootstrap.sh
```

### Skip ALB Controller Installation

```bash
# If using different ingress controller (NGINX, etc.)
export AUTO_INSTALL_ALB_CONTROLLER="false"
./scripts/bootstrap.sh
```

### Custom Namespace Names

```bash
# Use different namespaces
export APP_NAMESPACE="production"
export ARGOCD_NAMESPACE="gitops"

./scripts/bootstrap.sh
```

## Next Steps After Bootstrap

### 1. Verify Deployment

```bash
# Check all applications are syncing
kubectl -n argocd get applications

# Monitor sync progress
kubectl -n argocd describe application front-end
```

### 2. Access ArgoCD UI

```bash
# Port-forward to ArgoCD
kubectl -n argocd port-forward svc/argocd-server 8080:443

# In browser: https://localhost:8080
# Username: admin
# Password: (retrieve from secret)

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### 3. Access Applications

```bash
# Get ingress endpoints
kubectl -n mogambo get ingress

# Get service ports
kubectl -n mogambo get svc
```

### 4. Monitor Logs

```bash
# Watch catalogue service
kubectl -n mogambo logs -f deployment/catalogue

# Watch carts service
kubectl -n mogambo logs -f deployment/carts

# Watch front-end
kubectl -n mogambo logs -f deployment/front-end
```

### 5. Verify Database Connectivity

```bash
# Check catalogue-db init job
kubectl -n mogambo get job
kubectl -n mogambo logs job/catalogue-db-init

# Check RDS connection from pod
kubectl -n mogambo run debug --image=mysql:8 -it -- \
  mysql -h RDS-ENDPOINT -u mogambo -p CATALOGUE_DB
```

## Rollback/Cleanup

If bootstrap fails midway or you need to restart:

```bash
# Option 1: Cleanup and re-run bootstrap
./scripts/cleanup.sh --dry-run  # See what will be removed
./scripts/cleanup.sh             # Remove everything
./scripts/bootstrap.sh           # Fresh start

# Option 2: Partial cleanup (remove only applications)
kubectl delete applications -n argocd --all

# Option 3: Restart specific component
kubectl -n argocd delete pod -l app.kubernetes.io/name=argocd-server
```

## Monitoring Resource Usage

```bash
# Node capacity
kubectl top nodes

# Pod resource usage
kubectl top pods -n mogambo
kubectl top pods -n argocd
kubectl top pods -n kube-system

# Storage usage
kubectl get pvc -A
df -h
```

## Performance Tuning

### Increase ArgoCD Sync Frequency

```bash
# Edit ApplicationSet controller
kubectl -n argocd edit configmap argocd-cmd-params-cm

# Add or modify:
# application.instanceLabelKey: argocd.argoproj.io/instance
# server.insecure: true
# server.rootpath: /
```

### Increase Database Connection Pool

Modify catalogue service environment (via ArgoCD app values):

```yaml
env:
  - name: DATABASE_POOL_SIZE
    value: "20"
```

## Security Considerations

### 1. Secret Management

```bash
# Don't commit .env files
echo "scripts/.env" >> .gitignore

# Use AWS Secrets Manager for production
aws secretsmanager create-secret \
  --name mogambo/rds-credentials \
  --secret-string '{"username":"mogambo","password":"SecurePass"}'
```

### 2. RBAC and Network Policies

```bash
# Verify RBAC roles
kubectl get rolebindings -n mogambo
kubectl get clusterrolebindings | grep mogambo

# Enable network policies
kubectl apply -f deploy/network-policies/
```

### 3. TLS/SSL

```bash
# Check certificate status
kubectl -n mogambo get certificate

# Renew if needed
kubectl -n mogambo delete certificate --all
```

## Performance Benchmarks

Typical bootstrap execution times:

| Phase | Duration | Notes |
|-------|----------|-------|
| Prerequisites check | ~10s | Local validation |
| AWS authentication | ~20s | API calls to AWS |
| Namespace creation | ~5s | Kubernetes operations |
| Secret creation | ~10s | Config application |
| ALB controller install | ~60s | Helm chart deployment |
| ArgoCD installation | ~120s | Large manifests |
| Application sync | ~180s | Depends on pod startup |
| **Total** | **~7-10 min** | One-time operation |

## Related Documentation

- [Cleanup Guide](./cleanup-guide.md) - Teardown procedures
- [Troubleshooting](./troubleshooting.md) - Common issues and solutions
- [Bootstrap vs Cleanup](./bootstrap-vs-cleanup.md) - Workflow comparison
- [Monitoring Guide](./monitoring.md) - Observability setup
- [Terraform README](../infra/README.md) - Infrastructure details

## Support and Issues

For detailed troubleshooting:

```bash
# Collect diagnostic info
kubectl cluster-info
kubectl get nodes -o wide
kubectl -n mogambo get events
kubectl -n argocd get events

# Check script logs
# (output printed to stdout during execution)
```

## Additional Resources

- [ArgoCD Documentation](https://argoproj.github.io/argo-cd/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
