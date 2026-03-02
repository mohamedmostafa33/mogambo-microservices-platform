output "alb_sg_id" {
  description = "Security Group ID for the Application Load Balancer"
  value       = aws_security_group.mogambo_alb_sg.id
}

output "eks_node_group_sg_id" {
  description = "Security Group ID for the EKS Node Group"
  value       = aws_security_group.mogambo_eks_node_group_sg.id
}

output "catalogue_db_sg_id" {
  description = "Security Group ID for the Catalogue Database (RDS)"
  value       = aws_security_group.mogambo_catalogue_db_sg.id
}

