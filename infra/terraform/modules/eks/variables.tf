variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
}

variable "eks_role_arn" {
  description = "The ARN of the IAM role for the EKS cluster"
  type        = string
}

variable "eks_subnet_ids" {
  description = "The subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "eks_node_group_name" {
  description = "The name of the EKS node group"
  type        = string
}

variable "eks_node_group_role_arn" {
  description = "The ARN of the IAM role for the EKS node group"
  type        = string
}

variable "eks_node_group_instance_type" {
  description = "The instance type for the EKS node group"
  type        = list(string)
}

variable "desired_node_count" {
  description = "The desired number of nodes in the EKS node group"
  type        = number
}

variable "max_node_count" {
  description = "The maximum number of nodes in the EKS node group" 
  type        = number
}

variable "min_node_count" {
  description = "The minimum number of nodes in the EKS node group"
  type        = number
}