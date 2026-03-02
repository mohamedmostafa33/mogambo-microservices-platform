resource "aws_eks_cluster" "mogambo_eks_cluster" {
  name     = var.cluster_name
  version  = var.kubernetes_version

  role_arn = var.eks_role_arn

  vpc_config {
    subnet_ids              = var.eks_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_eks_node_group" "mogambo_eks_node_group" {
  cluster_name    = aws_eks_cluster.mogambo_eks_cluster.name
  node_group_name = var.eks_node_group_name
  node_role_arn   = var.eks_node_group_role_arn

  subnet_ids      = var.eks_subnet_ids

  instance_types  = [var.eks_node_group_instance_type]

  scaling_config {
    desired_size = var.desired_node_count
    max_size     = var.max_node_count
    min_size     = var.min_node_count
  }

  tags = {
    Name = var.eks_node_group_name
  }

  depends_on = [aws_eks_cluster.mogambo_eks_cluster]
}