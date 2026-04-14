#!/usr/bin/env bash

# ------------------------------------------------------------
# Mogambo Platform Bootstrap Script
# ------------------------------------------------------------
# Purpose:
#   Prepare a fresh EKS cluster for ArgoCD App-of-Apps deployment.
#
# What it does:
#   1) Validates local prerequisites and environment variables
#   2) Authenticates against AWS and updates kubeconfig
#   3) Ensures required namespaces and Kubernetes secrets exist
#   4) Optionally installs cluster dependencies (EBS CSI / ALB controller)
#   5) Ensures IngressClass (alb) exists
#   6) Optionally installs ArgoCD
#   7) Applies ArgoCD root app and waits for child apps
#
# Notes:
#   - This script is intentionally idempotent where possible.
#   - Secrets are sourced from scripts/.env unless overridden.
# ------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
err() { printf '[ERROR] %s\n' "$*"; }

step() {
	printf '\n============================================\n'
	printf '  %s\n' "$*"
	printf '============================================\n'
}

usage() {
	cat <<'EOF'
Usage: ./bootstrap.sh [--env-file /path/to/.env]

Bootstraps the Mogambo EKS cluster for ArgoCD App-of-Apps deployment.
It can automatically:
	- update kubeconfig
	- ensure required namespaces exist
	- create required application secrets from .env
	- install/upgrade ArgoCD
	- optionally install AWS Load Balancer Controller
	- optionally install EBS CSI addon
	- apply root ArgoCD app

EOF
}

# -----------------------------
# Helpers
# -----------------------------
bool_true() {
	case "${1:-false}" in
		true|TRUE|1|yes|YES|y|Y) return 0 ;;
		*) return 1 ;;
	esac
}

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		err "Missing required command: $1"
		exit 1
	fi
}

is_placeholder_arn() {
	local v="${1:-}"
	[[ -z "$v" || "$v" == *"<"* || "$v" == *">"* || "$v" == *"ACCOUNT_ID"* || "$v" == *"ALB_CONTROLLER_IRSA_ROLE"* ]]
}

ensure_eks_oidc_provider() {
	local cluster_name="$1"
	local region="$2"
	local account_id="$3"
	local oidc_issuer oidc_provider oidc_provider_arn oidc_host thumbprint

	oidc_issuer="$(aws eks describe-cluster --name "$cluster_name" --region "$region" --query 'cluster.identity.oidc.issuer' --output text)"
	if [[ -z "$oidc_issuer" || "$oidc_issuer" == "None" ]]; then
		err "Could not resolve OIDC issuer for cluster $cluster_name"
		exit 1
	fi

	oidc_provider="${oidc_issuer#https://}"
	oidc_provider_arn="arn:aws:iam::${account_id}:oidc-provider/${oidc_provider}"

	if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_provider_arn" >/dev/null 2>&1; then
		log "IAM OIDC provider already exists: $oidc_provider_arn" >&2
		echo "$oidc_provider"
		return 0
	fi

	log "Creating IAM OIDC provider for EKS IRSA" >&2
	oidc_host="${oidc_provider%%/*}"
	thumbprint="$(
		echo | openssl s_client -servername "$oidc_host" -showcerts -connect "$oidc_host":443 2>/dev/null \
		| awk '/BEGIN CERTIFICATE/{cert=""} {cert=cert $0 "\n"} /END CERTIFICATE/{last_cert=cert} END{printf "%s", last_cert}' \
		| openssl x509 -fingerprint -sha1 -noout \
		| cut -d= -f2 \
		| tr -d ':' \
		| tr 'A-F' 'a-f'
	)"

	if [[ -z "$thumbprint" ]]; then
		err "Failed to compute OIDC thumbprint for $oidc_host"
		exit 1
	fi

	aws iam create-open-id-connect-provider \
		--url "$oidc_issuer" \
		--thumbprint-list "$thumbprint" \
		--client-id-list sts.amazonaws.com >/dev/null

	log "Created IAM OIDC provider: $oidc_provider_arn" >&2
	echo "$oidc_provider"
}

ensure_alb_controller_role_arn() {
	local cluster_name="$1"
	local region="$2"
	local role_name="$3"
	local policy_name="$4"
	local account_id policy_arn role_arn oidc_provider
	local trust_doc policy_doc

	account_id="$(aws sts get-caller-identity --query Account --output text)"
	policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"
	role_arn="arn:aws:iam::${account_id}:role/${role_name}"

	oidc_provider="$(ensure_eks_oidc_provider "$cluster_name" "$region" "$account_id")"

	policy_doc="$(mktemp)"
	trust_doc="$(mktemp)"
	trap 'rm -f "$policy_doc" "$trust_doc"' RETURN

	curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json" -o "$policy_doc"

	if aws iam get-policy --policy-arn "$policy_arn" >/dev/null 2>&1; then
		log "ALB controller IAM policy already exists: $policy_arn" >&2
	else
		log "Creating ALB controller IAM policy: $policy_name" >&2
		aws iam create-policy --policy-name "$policy_name" --policy-document "file://$policy_doc" >/dev/null
	fi

	cat > "$trust_doc" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${account_id}:oidc-provider/${oidc_provider}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${oidc_provider}:aud": "sts.amazonaws.com",
          "${oidc_provider}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }
  ]
}
EOF

	if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
		log "ALB controller IAM role already exists: $role_name (updating trust policy)" >&2
		aws iam update-assume-role-policy --role-name "$role_name" --policy-document "file://$trust_doc" >/dev/null
	else
		log "Creating ALB controller IAM role: $role_name" >&2
		aws iam create-role --role-name "$role_name" --assume-role-policy-document "file://$trust_doc" >/dev/null
	fi

	if [[ "$(aws iam list-attached-role-policies --role-name "$role_name" --query "AttachedPolicies[?PolicyArn=='${policy_arn}'] | length(@)" --output text)" != "1" ]]; then
		log "Attaching IAM policy to role" >&2
		aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn" >/dev/null
	fi

	echo "$role_arn"
}

resolve_alb_vpc_id() {
	local cluster_name="$1"
	local region="$2"
	local cluster_subnet_id vpc_id

	cluster_subnet_id="$(aws eks describe-cluster --name "$cluster_name" --region "$region" --query 'cluster.resourcesVpcConfig.subnetIds[0]' --output text)"
	if [[ -z "$cluster_subnet_id" || "$cluster_subnet_id" == "None" ]]; then
		err "Could not resolve a subnet ID for EKS cluster $cluster_name"
		exit 1
	fi

	vpc_id="$(aws ec2 describe-subnets --subnet-ids "$cluster_subnet_id" --region "$region" --query 'Subnets[0].VpcId' --output text)"
	if [[ -z "$vpc_id" || "$vpc_id" == "None" ]]; then
		err "Could not resolve VPC ID from subnet $cluster_subnet_id"
		exit 1
	fi

	echo "$vpc_id"
}

ensure_alb_controller_extra_permissions() {
	local role_name="$1"
	local policy_doc

	policy_doc="$(mktemp)"
	trap 'rm -f "$policy_doc"' RETURN

	cat > "$policy_doc" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
				"ec2:DescribeRouteTables",
				"ec2:GetSecurityGroupsForVpc"
			],
			"Resource": "*"
		},
		{
			"Effect": "Allow",
			"Action": [
				"elasticloadbalancing:DescribeListenerAttributes",
				"elasticloadbalancing:ModifyListenerAttributes"
      ],
      "Resource": "*"
    }
  ]
}
EOF

	aws iam put-role-policy \
		--role-name "$role_name" \
		--policy-name "AddedMissingPermissions" \
		--policy-document "file://$policy_doc" >/dev/null
}

ensure_alb_discovery_subnet_tags() {
	local cluster_name="$1"
	local region="$2"
	local vpc_id="$3"
	local subnet_id map_public_ip

	while read -r subnet_id map_public_ip; do
		[[ -z "$subnet_id" ]] && continue

		if [[ "$map_public_ip" == "True" ]]; then
			aws ec2 create-tags \
				--resources "$subnet_id" \
				--tags "Key=kubernetes.io/cluster/${cluster_name},Value=shared" "Key=kubernetes.io/role/elb,Value=1" \
				--region "$region" >/dev/null
		else
			aws ec2 create-tags \
				--resources "$subnet_id" \
				--tags "Key=kubernetes.io/cluster/${cluster_name},Value=shared" "Key=kubernetes.io/role/internal-elb,Value=1" \
				--region "$region" >/dev/null
		fi
	done < <(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --region "$region" --query 'Subnets[*].[SubnetId,MapPublicIpOnLaunch]' --output text)
}

wait_for_deployment() {
	local namespace="$1"
	local deployment="$2"
	local timeout="${3:-600s}"
	kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout="$timeout"
}

wait_for_statefulset() {
	local namespace="$1"
	local statefulset="$2"
	local timeout="${3:-600s}"
	kubectl -n "$namespace" rollout status "statefulset/$statefulset" --timeout="$timeout"
}

upsert_secret_literal() {
	local namespace="$1"
	local secret_name="$2"
	shift 2

	kubectl -n "$namespace" create secret generic "$secret_name" "$@" \
		--dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

validate_secret_formats() {
	if [[ "$CATALOGUE_DB_DSN" == *"REPLACE_RDS_ENDPOINT"* || "$DATABASE_URL" == *"REPLACE_RDS_ENDPOINT"* ]]; then
		err "RDS endpoint placeholder is still present in .env. Replace REPLACE_RDS_ENDPOINT first."
		exit 1
	fi

	if ! printf '%s' "$CATALOGUE_DB_DSN" | grep -Eq '^[^:]+:.+@tcp\([^)]+:[0-9]+\)/[^[:space:]]+$'; then
		err "CATALOGUE_DB_DSN format invalid. Expected: user:password@tcp(host:3306)/database"
		exit 1
	fi

	if ! printf '%s' "$DATABASE_URL" | grep -Eq '^mysql://[^:]+:.+@[^:/]+:[0-9]+/[^[:space:]]+$'; then
		err "DATABASE_URL format invalid. Expected: mysql://user:password@host:3306/database"
		exit 1
	fi
}

resolve_cluster_name_from_terraform() {
	local tf_dir="$REPO_ROOT/infra/terraform/environments/dev"
	if [[ -d "$tf_dir" ]] && command -v terraform >/dev/null 2>&1; then
		terraform -chdir="$tf_dir" output -raw eks_cluster_name 2>/dev/null || true
	fi
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--env-file)
				ENV_FILE="$2"
				shift 2
				;;
			-h|--help)
				usage
				exit 0
				;;
			*)
				err "Unknown option: $1"
				usage
				exit 1
				;;
		esac
	done
}

parse_args "$@"

# -----------------------------
# Step 0: Load Configuration
# -----------------------------
step "Step 0: Load Configuration"
if [[ -f "$ENV_FILE" ]]; then
	log "Loading environment from $ENV_FILE"
	set -a
	# shellcheck source=/dev/null
	source "$ENV_FILE"
	set +a
else
	warn "Env file not found: $ENV_FILE (continuing with current environment variables)"
fi

# -----------------------------
# Step 1: Local Prerequisites
# -----------------------------
step "Step 1: Validate Local Prerequisites"
require_cmd aws
require_cmd kubectl
require_cmd helm
require_cmd curl
require_cmd openssl

AWS_REGION="${AWS_REGION:-us-east-1}"
APP_NAMESPACE="${APP_NAMESPACE:-mogambo}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_ROOT_APP_MANIFEST="${ARGOCD_ROOT_APP_MANIFEST:-$REPO_ROOT/deploy/argocd/root-app.yaml}"
ARGOCD_INSTALL_MANIFEST_URL="${ARGOCD_INSTALL_MANIFEST_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

AUTO_INSTALL_ARGOCD="${AUTO_INSTALL_ARGOCD:-true}"
AUTO_INSTALL_ALB_CONTROLLER="${AUTO_INSTALL_ALB_CONTROLLER:-false}"
AUTO_INSTALL_EBS_CSI_ADDON="${AUTO_INSTALL_EBS_CSI_ADDON:-false}"

AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME="${AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME:-mogambo-aws-load-balancer-controller-role}"
AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME="${AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME:-AWSLoadBalancerControllerIAMPolicy-Mogambo}"

EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-}"
if [[ -z "$EKS_CLUSTER_NAME" ]]; then
	EKS_CLUSTER_NAME="$(resolve_cluster_name_from_terraform)"
fi
if [[ -z "$EKS_CLUSTER_NAME" ]]; then
	err "EKS_CLUSTER_NAME is not set and could not be resolved from Terraform outputs."
	exit 1
fi

if [[ "$ARGOCD_ROOT_APP_MANIFEST" != /* ]]; then
	ARGOCD_ROOT_APP_MANIFEST="$REPO_ROOT/$ARGOCD_ROOT_APP_MANIFEST"
fi

if [[ -z "${CATALOGUE_DB_DSN:-}" || -z "${DATABASE_URL:-}" ]]; then
	err "Missing required secrets. Ensure CATALOGUE_DB_DSN and DATABASE_URL are set in .env"
	exit 1
fi

validate_secret_formats

log "Using cluster: $EKS_CLUSTER_NAME"
log "Using region:  $AWS_REGION"

# -----------------------------
# Step 2: AWS + Kube Auth
# -----------------------------
step "Step 2: Authenticate AWS and Configure kubectl"
log "Validating AWS identity"
aws sts get-caller-identity >/dev/null

log "Updating kubeconfig"
aws eks update-kubeconfig --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" >/dev/null

log "Verifying Kubernetes access"
kubectl get nodes >/dev/null

# -----------------------------
# Step 3: Namespaces + Secrets
# -----------------------------
step "Step 3: Ensure Namespaces and Required Secrets"
log "Ensuring namespaces exist"
kubectl create namespace "$APP_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

log "Creating required application secrets"
upsert_secret_literal "$APP_NAMESPACE" "catalogue-db-connection-secret" \
	--from-literal=CATALOGUE_DB_DSN="$CATALOGUE_DB_DSN"

upsert_secret_literal "$APP_NAMESPACE" "catalogue-db-migrate-secret" \
	--from-literal=DATABASE_URL="$DATABASE_URL"

# -----------------------------
# Step 4: Optional EBS CSI
# -----------------------------
step "Step 4: Storage Prerequisites"
if bool_true "$AUTO_INSTALL_EBS_CSI_ADDON"; then
	if aws eks describe-addon --cluster-name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --addon-name aws-ebs-csi-driver >/dev/null 2>&1; then
		log "EBS CSI addon already exists"
	else
		log "Installing EBS CSI addon"
		aws eks create-addon \
			--cluster-name "$EKS_CLUSTER_NAME" \
			--region "$AWS_REGION" \
			--addon-name aws-ebs-csi-driver \
			--resolve-conflicts OVERWRITE >/dev/null
	fi
fi

log "Checking storage classes"
if [[ "$(kubectl get storageclass -o name | wc -l | tr -d ' ')" == "0" ]]; then
	err "No StorageClass found. carts-db StatefulSet provisioning will fail."
	exit 1
fi

if kubectl get storageclass gp2 >/dev/null 2>&1; then
	if [[ "$(kubectl get storageclass gp2 -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null || true)" != "true" ]]; then
		log "Marking gp2 as default StorageClass"
		kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=true --overwrite >/dev/null
	fi
fi

# -----------------------------
# Step 5: Optional ALB Controller
# -----------------------------
step "Step 5: Ingress Prerequisites"
if bool_true "$AUTO_INSTALL_ALB_CONTROLLER"; then
	if is_placeholder_arn "${AWS_LOAD_BALANCER_CONTROLLER_IAM_ROLE_ARN:-}"; then
		log "Resolving ALB controller IAM role automatically"
		AWS_LOAD_BALANCER_CONTROLLER_IAM_ROLE_ARN="$(ensure_alb_controller_role_arn "$EKS_CLUSTER_NAME" "$AWS_REGION" "$AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME" "$AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME")"
		log "Using ALB controller IAM role: $AWS_LOAD_BALANCER_CONTROLLER_IAM_ROLE_ARN"
	fi

	ALB_VPC_ID="$(resolve_alb_vpc_id "$EKS_CLUSTER_NAME" "$AWS_REGION")"
	log "Resolved ALB VPC: $ALB_VPC_ID"
	log "Ensuring ALB controller role has subnet discovery permissions"
	ensure_alb_controller_extra_permissions "$AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME"
	log "Ensuring ALB discovery subnet tags are present"
	ensure_alb_discovery_subnet_tags "$EKS_CLUSTER_NAME" "$AWS_REGION" "$ALB_VPC_ID"

	if kubectl -n kube-system get deployment aws-load-balancer-controller >/dev/null 2>&1; then
		log "AWS Load Balancer Controller already installed; reconciling Helm values"
	else
		log "Installing AWS Load Balancer Controller"
	fi

	helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
	helm repo update >/dev/null

	kubectl -n kube-system create serviceaccount aws-load-balancer-controller --dry-run=client -o yaml | kubectl apply -f - >/dev/null
	kubectl -n kube-system annotate serviceaccount aws-load-balancer-controller \
		"eks.amazonaws.com/role-arn=${AWS_LOAD_BALANCER_CONTROLLER_IAM_ROLE_ARN}" --overwrite >/dev/null

	helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
		-n kube-system \
		--set clusterName="$EKS_CLUSTER_NAME" \
		--set region="$AWS_REGION" \
		--set vpcId="$ALB_VPC_ID" \
		--set createIngressClassResource=false \
		--set serviceAccount.create=false \
		--set serviceAccount.name=aws-load-balancer-controller \
		--set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$AWS_LOAD_BALANCER_CONTROLLER_IAM_ROLE_ARN" >/dev/null

	kubectl -n kube-system rollout restart deployment/aws-load-balancer-controller >/dev/null 2>&1 || true
else
	if ! kubectl -n kube-system get deployment aws-load-balancer-controller >/dev/null 2>&1; then
		warn "AWS Load Balancer Controller is not installed. Ingress with class 'alb' will not work."
	fi
fi

if ! kubectl get ingressclass alb >/dev/null 2>&1; then
	log "Creating IngressClass alb"
	cat <<'EOF' | kubectl apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
spec:
  controller: ingress.k8s.aws/alb
EOF
fi

# -----------------------------
# Step 6: ArgoCD Installation
# -----------------------------
step "Step 6: Install/Validate ArgoCD"
if bool_true "$AUTO_INSTALL_ARGOCD"; then
	log "Installing/Upgrading ArgoCD"
	kubectl apply -n "$ARGOCD_NAMESPACE" --server-side -f "$ARGOCD_INSTALL_MANIFEST_URL" >/dev/null
	wait_for_deployment "$ARGOCD_NAMESPACE" argocd-server 600s
	wait_for_deployment "$ARGOCD_NAMESPACE" argocd-repo-server 600s
	wait_for_deployment "$ARGOCD_NAMESPACE" argocd-applicationset-controller 600s
	wait_for_statefulset "$ARGOCD_NAMESPACE" argocd-application-controller 600s
fi

if [[ ! -f "$ARGOCD_ROOT_APP_MANIFEST" ]]; then
	err "Root app manifest not found: $ARGOCD_ROOT_APP_MANIFEST"
	exit 1
fi

# -----------------------------
# Step 7: App-of-Apps Deploy
# -----------------------------
step "Step 7: Apply ArgoCD Root App"
log "Applying ArgoCD root app"
kubectl apply -f "$ARGOCD_ROOT_APP_MANIFEST" >/dev/null

log "Waiting for ArgoCD Applications to appear"
for app in front-end catalogue catalogue-db carts carts-db; do
	for i in {1..30}; do
		if kubectl -n "$ARGOCD_NAMESPACE" get application "$app" >/dev/null 2>&1; then
			break
		fi
		sleep 5
	done
done

# -----------------------------
# Step 8: Final Summary
# -----------------------------
step "Step 8: Bootstrap Complete"
log "Bootstrap complete"
echo
echo "Cluster: $EKS_CLUSTER_NAME"
echo "App namespace: $APP_NAMESPACE"
echo "ArgoCD namespace: $ARGOCD_NAMESPACE"
echo
echo "Quick checks:"
echo "  kubectl -n $ARGOCD_NAMESPACE get applications"
echo "  kubectl -n $APP_NAMESPACE get pods,svc,ingress"
echo "  kubectl -n $APP_NAMESPACE get jobs"
echo "  kubectl -n $APP_NAMESPACE logs job/catalogue-db-init --tail=100"

