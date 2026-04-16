# Mogambo Platform Cleanup Guide

## Overview

The `cleanup.sh` script safely removes all Kubernetes and AWS resources created by `bootstrap.sh`, preparing the cluster for infrastructure destruction with Terraform.

## When to Use

Run this script **before** executing `terraform destroy`:

```bash
# Preview changes first
./scripts/cleanup.sh --dry-run

# Execute cleanup (with confirmations)
./scripts/cleanup.sh

# Force cleanup without prompts (use with caution)
./scripts/cleanup.sh --force --skip-oidc
```

## What It Cleans Up

### 1. ArgoCD Applications
- Removes all ArgoCD `Application` resources
- Triggers cascade deletion of managed workloads (deployments, statefulsets, etc.)
- **Impact**: Services stop running

### 2. Helm Releases
- Uninstalls all Helm charts across namespaces:
  - `kube-system`: AWS Load Balancer Controller
  - `argocd`: ArgoCD itself (if installed via Helm)
  - `mogambo`: Application charts (if any)
- **Impact**: Removes operator-managed resources

### 3. AWS Load Balancers
- Discovers and deletes all ALBs/NLBs created by Kubernetes Ingress resources
- Searches by VPC association with the EKS cluster
- **Impact**: Ingress endpoints become unavailable

### 4. IAM Resources
- Removes ALB Controller service role
- Detaches and deletes associated IAM policies
- Inline policies are removed
- **Impact**: AWS Load Balancer Controller cannot authenticate post-cleanup

### 5. OIDC Provider (Optional)
- Removes the IAM OIDC provider for EKS IRSA (service account authentication)
- **Warning**: Only delete if no other services depend on it
- **Skip with**: `--skip-oidc` flag

### 6. Kubernetes Namespaces
- Deletes `mogambo` namespace (application workload namespace)
- Deletes `argocd` namespace (GitOps namespace)
- All resources within are cascade-deleted
- **Impact**: Complete removal of deployed services and configuration

## Safety Features

### Dry-Run Mode
Preview all operations without making changes:
```bash
./scripts/cleanup.sh --dry-run
```

### Interactive Confirmations
Each major operation requires confirmation:
```
? Delete all ArgoCD applications [y/N]:
```

### Force Mode
Skip confirmations (use carefully):
```bash
./scripts/cleanup.sh --force --skip-oidc
```

### Detailed Logging
Every action is logged with timestamps:
```
[INFO] Found ArgoCD applications: carts carts-db catalogue...
[INFO] Deleting application: carts
[OK] ArgoCD applications removed
```

## Quick Reference Commands

### Prerequisites
```bash
# Ensure these commands are available
which kubectl helm aws jq
```

### Load Configuration
```bash
# Load cluster settings from .env
source scripts/.env
```

### Verify Cleanup State
```bash
# Check namespaces removed
kubectl get namespaces

# Check applications removed
kubectl get applications -A

# Check Helm releases removed
helm list -A

# Check load balancers removed
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query 'LoadBalancers[?VpcId].LoadBalancerName' \
  --output text

# Check IAM role removed
aws iam list-roles \
  --query "Roles[?RoleName=='mogambo-aws-load-balancer-controller-role']"
```

## Workflow: Bootstrap → Deploy → Cleanup → Destroy

### 1. Initial Setup
```bash
./scripts/bootstrap.sh
# Creates: namespaces, secrets, ArgoCD, ALB controller, OIDC provider
```

### 2. Deploy Applications
```bash
kubectl apply -f deploy/argocd/root-app.yaml
# Creates: services, pods, ingresses, load balancers
```

### 3. Cleanup Before Destruction
```bash
./scripts/cleanup.sh
# Removes: applications, load balancers, IAM, OIDC, namespaces
```

### 4. Destroy Infrastructure
```bash
cd infra/terraform/environments/dev
terraform destroy
# Removes: EKS, VPC, RDS, EC2, etc.
```

## Common Scenarios

### Scenario 1: Full Cluster Teardown
```bash
# 1. Dry-run to verify
./scripts/cleanup.sh --dry-run

# 2. Execute cleanup
./scripts/cleanup.sh

# 3. Verify cleanup
kubectl get namespaces  # Should show only system namespaces
helm list -A            # Should show only system Helm releases
aws elbv2 describe-load-balancers --region us-east-1 --query 'LoadBalancers[?VpcId]'

# 4. Destroy infrastructure
cd infra/terraform/environments/dev
terraform destroy -auto-approve
```

### Scenario 2: Remove Only Services (Keep Infrastructure)
```bash
# Just remove applications and load balancers
./scripts/cleanup.sh --force

# Don't remove namespaces (manual so you keep data)
# Don't run terraform destroy
```

### Scenario 3: Emergency Cleanup
```bash
# Force removal without prompts
./scripts/cleanup.sh --force --skip-oidc

# Useful for CI/CD pipelines or automated teardown
```

## Troubleshooting

### Load Balancer Cleanup Fails
If an ALB fails to delete:
```bash
# Check remaining target groups
aws elbv2 describe-target-groups --region us-east-1

# Check remaining listeners
aws elbv2 describe-listeners \
  --load-balancer-arn <your-alb-arn> \
  --region us-east-1

# Manually delete if necessary
aws elbv2 delete-load-balancer --load-balancer-arn <arn> --region us-east-1
```

### Namespace Stuck in Terminating State
If a namespace doesn't delete:
```bash
# Check for finalizers
kubectl get namespace mogambo -o yaml

# Remove finalizers if necessary
kubectl patch namespace mogambo -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### IAM Role Still Exists
If role deletion fails:
```bash
# Check attached policies
aws iam list-attached-role-policies --role-name mogambo-aws-load-balancer-controller-role

# List inline policies
aws iam list-role-policies --role-name mogambo-aws-load-balancer-controller-role

# Manually detach/delete if necessary
aws iam delete-role --role-name mogambo-aws-load-balancer-controller-role
```

## Advanced: Selective Cleanup

### Remove Only ArgoCD
```bash
# Manual deletion
kubectl delete applications -n argocd --all
kubectl delete namespace argocd
```

### Remove Only Load Balancers
```bash
# Get ALB ARNs and delete individually
aws elbv2 delete-load-balancer \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:ACCOUNT:loadbalancer/app/... \
  --region us-east-1
```

### Preserve OIDC for Other Services
```bash
# Use flag to skip OIDC deletion
./scripts/cleanup.sh --skip-oidc

# Or manually verify dependencies before deleting
aws iam get-role --role-name mogambo-aws-load-balancer-controller-role --query 'Role.AssumeRolePolicyDocument'
```

## Best Practices

1. **Always Dry-Run First**
   ```bash
   ./scripts/cleanup.sh --dry-run
   ```

2. **Keep Backups**
   - Backup RDS snapshots before cleanup
   - Export S3 data if needed
   - Save ArgoCD app definitions elsewhere

3. **Sequential Execution**
   - Run cleanup before Terraform destroy
   - Don't run both simultaneously
   - Wait for cleanup to complete before next step

4. **Monitor AWS Costs**
   - After cleanup, verify NAT gateways, EIPs are released
   - Check for orphaned resources:
     ```bash
     aws ec2 describe-addresses --region us-east-1
     aws ec2 describe-nat-gateways --region us-east-1
     ```

5. **Document Custom Resources**
   - If you added resources outside this setup, document them
   - Cleanup script won't remove them
   - Manually cleanup before `terraform destroy`

## Script Help
```bash
./scripts/cleanup.sh --help
```

## Environment Variables

Configure through `scripts/.env`:

```bash
export AWS_REGION="us-east-1"
export APP_NAMESPACE="mogambo"
export ARGOCD_NAMESPACE="argocd"
export EKS_CLUSTER_NAME="mogambo-eks-cluster"
export AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME="mogambo-aws-load-balancer-controller-role"
export AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy-Mogambo"
export SKIP_OIDC="false"
```

## Integration with CI/CD

For automated teardown in CI/CD pipelines:

```bash
#!/bin/bash
set -e

cd projects/mogambo-microservices-platform

# Cleanup with forced mode
./scripts/cleanup.sh --force --skip-oidc

# Destroy infrastructure
cd infra/terraform/environments/dev
terraform destroy -auto-approve
```

## Support & Issues

Common issues and their solutions are documented in [troubleshooting.md](./troubleshooting.md).

For more information on the bootstrap process, see [bootstrap-guide.md](./bootstrap-guide.md).
