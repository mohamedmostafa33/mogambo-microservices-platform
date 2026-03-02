output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.mogambo_eks_cluster.name
}

output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = aws_eks_cluster.mogambo_eks_cluster.arn
}

output "eks_cluster_endpoint" {
  description = "The API server endpoint of the EKS cluster"
  value       = aws_eks_cluster.mogambo_eks_cluster.endpoint
}

output "eks_node_group_name" {
  description = "The name of the EKS node group"
  value       = aws_eks_node_group.mogambo_eks_node_group.node_group_name
}

output "eks_node_group_arn" {
  description = "The ARN of the EKS node group"
  value       = aws_eks_node_group.mogambo_eks_node_group.arn
}