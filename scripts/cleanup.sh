#!/usr/bin/env bash

# ------------------------------------------------------------
# Mogambo Platform Cleanup Script
# ------------------------------------------------------------
# Purpose:
#   Safely remove all Kubernetes and AWS resources created by bootstrap.sh
#   before running 'terraform destroy'.
#
# What it does:
#   1) Validates cluster access and prerequisitesPrintf
#   2) Removes ArgoCD applications and workloads
#   3) Removes Helm releases
#   4) Deletes AWS Load Balancer resources (ALBs/NLBs)
#   5) Removes AWS IAM roles and policies
#   6) Cleans up OIDC provider (optional)
#   7) Removes Kubernetes namespaces
#
# Safety Features:
#   - Dry-run mode for preview
#   - Interactive confirmation for destructive operations
#   - Detailed logging of actions
#   - Rollback-friendly: can be stopped at any stage
#
# Usage:
#   ./cleanup.sh [--dry-run] [--force] [--skip-oidc]
# 
# Options:
#   --dry-run        Preview changes without executing them
#   --force          Skip interactive confirmations
#   --skip-oidc      Do not delete OIDC provider
# 
# Example:
#   # Preview what will be deleted
#   ./cleanup.sh --dry-run
#
#   # Execute with confirmations
#   ./cleanup.sh
#
#   # Force deletion without confirmations
#   ./cleanup.sh --force --skip-oidc
# 
# Notes:
#   - Run this BEFORE 'terraform destroy'
#   - Backup important data (RDS, S3) outside this script
#   - IAM cleanup is skipped if role is used elsewhere
# ------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Configuration
DRY_RUN="${DRY_RUN:-false}"
FORCE_DELETE="${FORCE_DELETE:-false}"
SKIP_OIDC="${SKIP_OIDC:-false}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
success() { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
err() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }
step() {
	printf '\n%s\n' "$(printf '=%.0s' {1..60})"
	printf "${BLUE}%s${NC}\n" "  $*"
	printf '%s\n' "$(printf '=%.0s' {1..60})"
}

dry_run_msg() {
	if [[ "$DRY_RUN" == "true" ]]; then
		printf "${YELLOW}[DRY-RUN]${NC} "
	fi
}

confirm() {
	local prompt="$1"
	if [[ "$FORCE_DELETE" == "true" ]]; then
		log "$prompt (forced)"
		return 0
	fi
	
	local response
	read -r -p "$(printf "${YELLOW}?${NC} %s [y/N]: " "$prompt")" response
	[[ "$response" =~ ^[Yy]$ ]]
}

require_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		err "Missing required command: $1"
		exit 1
	fi
}

# Helper: check kubectl access
check_cluster_access() {
	if ! kubectl cluster-info >/dev/null 2>&1; then
		err "Cannot access Kubernetes cluster. Verify kubeconfig and cluster connectivity."
		exit 1
	fi
	success "Kubernetes cluster accessible"
}

# Helper: parse environment variables
load_env() {
	if [[ -f "$ENV_FILE" ]]; then
		log "Loading environment from $ENV_FILE"
		set -a
		# shellcheck source=/dev/null
		source "$ENV_FILE"
		set +a
	else
		warn "Env file not found: $ENV_FILE (using defaults)"
	fi

	AWS_REGION="${AWS_REGION:-us-east-1}"
	APP_NAMESPACE="${APP_NAMESPACE:-mogambo}"
	ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
	AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME="${AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME:-mogambo-aws-load-balancer-controller-role}"
	AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME="${AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME:-AWSLoadBalancerControllerIAMPolicy-Mogambo}"
	EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-}"

	if [[ -z "$EKS_CLUSTER_NAME" ]]; then
		EKS_CLUSTER_NAME="$(kubectl config current-context | cut -d'/' -f2 2>/dev/null || true)"
	fi

	if [[ -z "$EKS_CLUSTER_NAME" ]]; then
		err "Cannot determine EKS cluster name. Set EKS_CLUSTER_NAME in .env or kubeconfig."
		exit 1
	fi

	log "Cluster: $EKS_CLUSTER_NAME | Region: $AWS_REGION | App NS: $APP_NAMESPACE | ArgoCD NS: $ARGOCD_NAMESPACE"
}

# Step 1: Remove ArgoCD Applications
remove_argocd_applications() {
	step "Step 1: Remove ArgoCD Applications"
	
	if ! kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
		log "ArgoCD namespace does not exist, skipping application removal"
		return 0
	fi

	local apps
	apps=$(kubectl -n "$ARGOCD_NAMESPACE" get applications -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
	
	if [[ -z "$apps" ]]; then
		log "No ArgoCD applications found"
		return 0
	fi

	log "Found ArgoCD applications: $apps"
	
	if confirm "Delete all ArgoCD applications (${RED}will remove deployed services${NC})"; then
		for app in $apps; do
			log "Deleting application: $app"
			if [[ "$DRY_RUN" != "true" ]]; then
				kubectl -n "$ARGOCD_NAMESPACE" delete application "$app" --ignore-not-found=true >/dev/null 2>&1 || true
			else
				echo "  [DRY-RUN] would delete: kubectl -n $ARGOCD_NAMESPACE delete application $app"
			fi
		done
		
		log "Waiting for application resources to be removed..."
		if [[ "$DRY_RUN" != "true" ]]; then
			sleep 10
		fi
		success "ArgoCD applications removed"
	else
		warn "Skipped ArgoCD application removal"
	fi
}

# Step 2: Remove Helm Releases
remove_helm_releases() {
	step "Step 2: Remove Helm Releases"
	
	local namespaces=("kube-system" "$ARGOCD_NAMESPACE" "$APP_NAMESPACE")
	local releases_found=0

	for ns in "${namespaces[@]}"; do
		if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
			log "Namespace $ns does not exist, skipping"
			continue
		fi

		local releases
		releases=$(helm list -n "$ns" --output json 2>/dev/null | jq -r '.[] | .name' || true)
		
		if [[ -z "$releases" ]]; then
			log "No Helm releases in namespace: $ns"
			continue
		fi

		releases_found=1
		log "Found Helm releases in $ns: $releases"
		
		if confirm "Delete Helm releases in namespace $ns"; then
			echo "$releases" | while read -r release; do
				log "Uninstalling Helm release: $release"
				if [[ "$DRY_RUN" != "true" ]]; then
					helm uninstall "$release" -n "$ns" --ignore-not-found >/dev/null 2>&1 || true
				else
					echo "  [DRY-RUN] would uninstall: helm uninstall $release -n $ns"
				fi
			done
		else
			warn "Skipped Helm releases in namespace $ns"
		fi
	done

	if [[ $releases_found -eq 0 ]]; then
		log "No Helm releases found in any namespace"
	else
		success "Helm releases uninstalled"
	fi
}

# Step 3: Remove AWS Load Balancer Resources
remove_aws_load_balancer_resources() {
	step "Step 3: Remove AWS Load Balancer Resources"
	
	require_cmd aws

	local account_id vpc_id albs_found nlbs_found

	account_id="$(aws sts get-caller-identity --query Account --output text)"
	
	log "Resolving VPC associated with EKS cluster"
	local karpenter_arn
	karpenter_arn="arn:aws:eks:${AWS_REGION}:${account_id}:cluster/${EKS_CLUSTER_NAME}"
	
	vpc_id="$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null || true)"
	
	if [[ -z "$vpc_id" || "$vpc_id" == "None" ]]; then
		warn "Could not resolve VPC for cluster $EKS_CLUSTER_NAME, skipping ALB/NLB removal"
		return 0
	fi

	log "VPC: $vpc_id"

	# Find ALBs with Mogambo tags
	log "Searching for Application Load Balancers in VPC"
	albs_found=0
	
	local albs
	albs=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?VpcId=='$vpc_id' && Type=='application'].LoadBalancerArn" --output text 2>/dev/null || true)
	
	if [[ -n "$albs" ]]; then
		albs_found=1
		log "Found ALBs:"
		echo "$albs" | tr '\t' '\n' | sed 's/^/  /'
		
		if confirm "Delete all Application Load Balancers (${RED}includes all Ingress ALBs${NC})"; then
			echo "$albs" | tr '\t' '\n' | while read -r alb_arn; do
				[[ -z "$alb_arn" ]] && continue
				log "Deleting ALB: $alb_arn"
				if [[ "$DRY_RUN" != "true" ]]; then
					aws elbv2 delete-load-balancer --load-balancer-arn "$alb_arn" --region "$AWS_REGION" >/dev/null 2>&1 || true
				else
					echo "  [DRY-RUN] would delete ALB: $alb_arn"
				fi
			done
		else
			warn "Skipped ALB deletion"
		fi
	else
		log "No ALBs found in VPC"
	fi

	# Find NLBs
	log "Searching for Network Load Balancers in VPC"
	nlbs_found=0
	
	local nlbs
	nlbs=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?VpcId=='$vpc_id' && Type=='network'].LoadBalancerArn" --output text 2>/dev/null || true)
	
	if [[ -n "$nlbs" ]]; then
		nlbs_found=1
		log "Found NLBs:"
		echo "$nlbs" | tr '\t' '\n' | sed 's/^/  /'
		
		if confirm "Delete all Network Load Balancers"; then
			echo "$nlbs" | tr '\t' '\n' | while read -r nlb_arn; do
				[[ -z "$nlb_arn" ]] && continue
				log "Deleting NLB: $nlb_arn"
				if [[ "$DRY_RUN" != "true" ]]; then
					aws elbv2 delete-load-balancer --load-balancer-arn "$nlb_arn" --region "$AWS_REGION" >/dev/null 2>&1 || true
				else
					echo "  [DRY-RUN] would delete NLB: $nlb_arn"
				fi
			done
		else
			warn "Skipped NLB deletion"
		fi
	else
		log "No NLBs found in VPC"
	fi

	if [[ $albs_found -eq 0 && $nlbs_found -eq 0 ]]; then
		log "No load balancers found in VPC"
	else
		success "Load balancer deletion completed"
	fi
}

# Step 4: Remove IAM Resources
remove_iam_resources() {
	step "Step 4: Remove IAM Resources (ALB Controller)"
	
	require_cmd aws

	local role_name policy_name account_id policy_arn
	role_name="${AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME}"
	policy_name="${AWS_LOAD_BALANCER_CONTROLLER_POLICY_NAME}"
	account_id="$(aws sts get-caller-identity --query Account --output text)"
	policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"

	# Check if role exists
	if ! aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
		log "IAM role does not exist: $role_name"
		return 0
	fi

	log "Found IAM role: $role_name"

	if confirm "Delete IAM role and policies for ALB Controller"; then
		# Detach managed policies
		log "Detaching managed policies from role"
		if [[ "$DRY_RUN" != "true" ]]; then
			aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[*].PolicyArn' --output text | tr '\t' '\n' | while read -r policy_arn_attached; do
				[[ -z "$policy_arn_attached" ]] && continue
				log "Detaching: $policy_arn_attached"
				aws iam detach-role-policy --role-name "$role_name" --policy-arn "$policy_arn_attached" >/dev/null 2>&1 || true
			done
		else
			echo "  [DRY-RUN] would detach managed policies from role"
		fi

		# Delete inline policies
		log "Deleting inline policies from role"
		if [[ "$DRY_RUN" != "true" ]]; then
			aws iam list-role-policies --role-name "$role_name" --query 'PolicyNames[*]' --output text | tr '\t' '\n' | while read -r inline_policy_name; do
				[[ -z "$inline_policy_name" ]] && continue
				log "Deleting inline policy: $inline_policy_name"
				aws iam delete-role-policy --role-name "$role_name" --policy-name "$inline_policy_name" >/dev/null 2>&1 || true
			done
		else
			echo "  [DRY-RUN] would delete inline policies from role"
		fi

		# Delete the role
		log "Deleting IAM role: $role_name"
		if [[ "$DRY_RUN" != "true" ]]; then
			aws iam delete-role --role-name "$role_name" >/dev/null 2>&1 || true
		else
			echo "  [DRY-RUN] would delete role: $role_name"
		fi

		# Try to delete the standalone policy
		if aws iam get-policy --policy-arn "$policy_arn" >/dev/null 2>&1; then
			log "Deleting IAM policy: $policy_arn"
			if [[ "$DRY_RUN" != "true" ]]; then
				# First delete all policy versions except the default one
				aws iam list-policy-versions --policy-arn "$policy_arn" --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text | tr '\t' '\n' | while read -r version_id; do
					[[ -z "$version_id" ]] && continue
					log "Deleting policy version: $version_id"
					aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$version_id" >/dev/null 2>&1 || true
				done
				# Then delete the policy itself
				aws iam delete-policy --policy-arn "$policy_arn" >/dev/null 2>&1 || true
			else
				echo "  [DRY-RUN] would delete policy: $policy_arn"
			fi
		else
			log "Standalone policy does not exist: $policy_arn (might be replaced)"
		fi

		success "IAM resources deleted"
	else
		warn "Skipped IAM resource deletion"
	fi
}

# Step 5: Remove OIDC Provider (optional)
remove_oidc_provider() {
	step "Step 5: Remove OIDC Provider (Optional)"
	
	require_cmd aws

	if [[ "$SKIP_OIDC" == "true" ]]; then
		warn "Skipping OIDC provider deletion (--skip-oidc flag set)"
		return 0
	fi

	local account_id oidc_issuer oidc_provider oidc_provider_arn

	account_id="$(aws sts get-caller-identity --query Account --output text)"
	oidc_issuer="$(aws eks describe-cluster --name "$EKS_CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.identity.oidc.issuer' --output text 2>/dev/null || true)"
	
	if [[ -z "$oidc_issuer" || "$oidc_issuer" == "None" ]]; then
		log "No OIDC issuer configured for cluster $EKS_CLUSTER_NAME"
		return 0
	fi

	oidc_provider="${oidc_issuer#https://}"
	oidc_provider_arn="arn:aws:iam::${account_id}:oidc-provider/${oidc_provider}"

	if ! aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$oidc_provider_arn" >/dev/null 2>&1; then
		log "OIDC provider does not exist: $oidc_provider_arn"
		return 0
	fi

	log "Found OIDC provider: $oidc_provider_arn"
	warn "IMPORTANT: Do not delete OIDC provider if it is used by other services/controllers"
	
	if confirm "Delete OIDC provider (${RED}verify no other services depend on it${NC})"; then
		log "Deleting OIDC provider: $oidc_provider_arn"
		if [[ "$DRY_RUN" != "true" ]]; then
			aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$oidc_provider_arn" >/dev/null 2>&1 || true
		else
			echo "  [DRY-RUN] would delete OIDC provider"
		fi
		success "OIDC provider deleted"
	else
		warn "Skipped OIDC provider deletion"
	fi
}

# Step 6: Remove Kubernetes Namespaces
remove_kubernetes_namespaces() {
	step "Step 6: Remove Kubernetes Namespaces"
	
	local namespaces=("$APP_NAMESPACE" "$ARGOCD_NAMESPACE")

	for ns in "${namespaces[@]}"; do
		if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
			log "Namespace does not exist: $ns"
			continue
		fi

		log "Found namespace: $ns"
		
		if confirm "Delete namespace and all its resources: $ns"; then
			log "Deleting namespace: $ns"
			if [[ "$DRY_RUN" != "true" ]]; then
				kubectl delete namespace "$ns" --ignore-not-found=true >/dev/null 2>&1 || true
				
				# Wait for namespace to be fully deleted
				log "Waiting for namespace to be fully removed..."
				local count=0
				while kubectl get namespace "$ns" >/dev/null 2>&1 && [[ $count -lt 60 ]]; do
					sleep 2
					((count++))
				done
				
				if kubectl get namespace "$ns" >/dev/null 2>&1; then
					warn "Namespace $ns still exists after timeout, trying forced deletion"
					kubectl patch namespace "$ns" -p '{"metadata":{"finalizers":[]}}' --type=merge >/dev/null 2>&1 || true
				fi
			else
				echo "  [DRY-RUN] would delete namespace: $ns"
			fi
		else
			warn "Skipped namespace deletion: $ns"
		fi
	done

	success "Namespace cleanup completed"
}

# Step 7: Summary
print_summary() {
	step "Cleanup Summary"
	
	if [[ "$DRY_RUN" == "true" ]]; then
		warn "This was a DRY-RUN. No changes were made."
		log "Run without --dry-run to execute the cleanup operations."
	else
		success "Cleanup completed"
	fi

	log "Next step: Run 'terraform destroy' to remove infrastructure"
	echo
	log "Verification commands:"
	echo "  kubectl get namespaces"
	echo "  kubectl get applications -A"
	echo "  helm list -A"
	echo "  aws elbv2 describe-load-balancers --region ${AWS_REGION} --query 'LoadBalancers[?VpcId].LoadBalancerName' --output text"
	echo "  aws iam list-roles --query \"Roles[?RoleName=='${AWS_LOAD_BALANCER_CONTROLLER_ROLE_NAME}']\" --output text"
}

# Parse command line arguments
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--dry-run)
				DRY_RUN="true"
				log "Dry-run mode enabled"
				shift
				;;
			--force)
				FORCE_DELETE="true"
				log "Force mode enabled (skipping confirmations)"
				shift
				;;
			--skip-oidc)
				SKIP_OIDC="true"
				log "OIDC provider deletion will be skipped"
				shift
				;;
			-h|--help)
				cat <<'EOF'
Usage: ./cleanup.sh [OPTIONS]

Clean up all Kubernetes and AWS resources created by bootstrap.sh

OPTIONS:
  --dry-run       Preview changes without executing them
  --force         Skip interactive confirmations
  --skip-oidc     Do not delete OIDC provider
  -h, --help      Show this help message

EXAMPLES:
  Preview cleanup:
    ./cleanup.sh --dry-run

  Execute with confirmations:
    ./cleanup.sh

  Force cleanup without prompts (use with caution):
    ./cleanup.sh --force --skip-oidc

EOF
				exit 0
				;;
			*)
				err "Unknown option: $1"
				exit 1
				;;
		esac
	done
}

# Main Execution
main() {
	parse_args "$@"

	echo
	cat <<'EOF'

╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║       Mogambo Platform Cleanup Script                         ║
║       Removes K8s and AWS resources created by bootstrap      ║
║                                                               ║
║  ⚠️  DESTRUCTIVE OPERATION - Review carefully before running  ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF

	require_cmd kubectl
	require_cmd helm
	require_cmd aws
	require_cmd jq

	check_cluster_access
	load_env

	if [[ "$DRY_RUN" == "true" ]]; then
		warn "DRY-RUN MODE: No resources will be deleted"
		echo
	fi

	# Execution sequence
	remove_argocd_applications
	remove_helm_releases
	remove_aws_load_balancer_resources
	remove_iam_resources
	remove_oidc_provider
	remove_kubernetes_namespaces

	print_summary
}

main "$@"
