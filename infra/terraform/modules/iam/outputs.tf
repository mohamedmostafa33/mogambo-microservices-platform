output "eks_cluster_role_name" {
  description = "The name of the IAM role for the EKS cluster"
  value       = aws_iam_role.mogambo_eks_role.name
}

output "eks_cluster_role_arn" {
  description = "The ARN of the IAM role for the EKS cluster"
  value       = aws_iam_role.mogambo_eks_role.arn
}

output "eks_node_group_role_name" {
  description = "The name of the IAM role for the EKS node group"
  value       = aws_iam_role.mogambo_eks_node_group_role.name
}

output "eks_node_group_role_arn" {
  description = "The ARN of the IAM role for the EKS node group"
  value       = aws_iam_role.mogambo_eks_node_group_role.arn
}

output "eks_node_group_policies" {
  description = "List of attached IAM policies for the node group role"
  value = [
    aws_iam_role_policy_attachment.mogambo_eks_node_group_role_policy_attachment.policy_arn,
    aws_iam_role_policy_attachment.mogambo_eks_cni_policy_attachment.policy_arn,
    aws_iam_role_policy_attachment.mogambo_eks_registry_policy_attachment.policy_arn
  ]
}

output "eks_cluster_policies" {
  description = "List of attached IAM policies for the cluster role"
  value = [
    aws_iam_role_policy_attachment.mogambo_eks_role_policy_attachment.policy_arn,
    aws_iam_role_policy_attachment.mogambo_eks_service_role_policy_attachment.policy_arn
  ]
}