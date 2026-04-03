resource "aws_iam_role" "mogambo_eks_role" {
  name = var.eks_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  }) 
}

resource "aws_iam_role_policy_attachment" "mogambo_eks_role_policy_attachment" {
  role       = aws_iam_role.mogambo_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "mogambo_eks_service_role_policy_attachment" {
  role       = aws_iam_role.mogambo_eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"

}

resource "aws_iam_role" "mogambo_eks_node_group_role" {
  name = var.eks_node_group_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  }) 
}

resource "aws_iam_role_policy_attachment" "mogambo_eks_node_group_role_policy_attachment" {
  role       = aws_iam_role.mogambo_eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "mogambo_eks_cni_policy_attachment" {
  role       = aws_iam_role.mogambo_eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "mogambo_eks_registry_policy_attachment" {
  role       = aws_iam_role.mogambo_eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}