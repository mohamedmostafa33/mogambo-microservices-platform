variable "eks_role_name" {
  description = "The name of the IAM role for the EKS cluster"
  type        = string
}

variable "eks_node_group_role_name" {
  description = "The name of the IAM role for the EKS node group"
  type        = string
}