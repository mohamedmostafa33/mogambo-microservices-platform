variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_block_1" {
  description = "CIDR block for the public subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr_block_2" {
  description = "CIDR block for the public subnet 2"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr_block_1" {
  description = "CIDR block for the private subnet 1"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr_block_2" {
  description = "CIDR block for the private subnet 2"
  type        = string
  default     = "10.0.4.0/24"
}

variable "db_subnet_group_name" {
  description = "The name of the DB subnet group to associate with the RDS instance"
  type        = string
  default     = "mogambo-db-subnet-group"
}

variable "db_engine" {
  description = "The Engine type for the RDS instance"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "The Engine version for the RDS instance"
  type        = string
  default     = "8.4.7"
}

variable "db_instance_class" {
  description = "The instance class for the RDS instance"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the RDS instance"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for the RDS instance"
  type        = number
  default     = 100
}

variable "db_identifier" {
  description = "The identifier for the RDS instance"
  type        = string
  default = "mogambo-catalogue-db-instance"
}

variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "mogambo_catalogue_db"
}

variable "db_username" {
  description = "The master username for the RDS instance"
  type        = string
  default     = "mogambo_user"
}

variable "db_password" {
  description = "The master password for the RDS instance"
  type        = string
  sensitive   = true
  default     = "Mogambo#2026!"
}

variable "frontend_repository_name" {
  description = "The name of the frontend ECR repository"
  type        = string
  default     = "mogambo-frontend"
}

variable "catalogue_repository_name" {
  description = "The name of the catalogue ECR repository"
  type        = string
  default     = "mogambo-catalogue"
}

variable "cart_repository_name" {
  description = "The name of the cart ECR repository"
  type        = string
  default     = "mogambo-cart"
}

variable "bucket_name" {
  description = "The name of the S3 bucket to create"
  type        = string
  default     = "mogambo-platform-bucket"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "cloudfront_price_class" {
  description = "CloudFront distribution price class"
  type        = string
  default     = "PriceClass_100"
}

variable "eks_role_name" {
  description = "The name of the IAM role for the EKS cluster"
  type        = string
  default = "mogambo-eks-cluster-role"
}

variable "eks_node_group_role_name" {
  description = "The name of the IAM role for the EKS node group"
  type        = string
  default     = "mogambo-eks-node-group-role"
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
  default     = "mogambo-eks-cluster"
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.35"
}

variable "eks_node_group_name" {
  description = "The name of the EKS node group"
  type        = string
  default     = "mogambo-eks-node-group"
}

variable "eks_node_group_instance_type" {
  description = "The instance type for the EKS node group"
  type        = string
  default     = "t3.small"
}

variable "desired_node_count" {
  description = "The desired number of nodes in the EKS node group"
  type        = number
  default     = 5
}

variable "max_node_count" {
  description = "The maximum number of nodes in the EKS node group" 
  type        = number
  default     = 6
}

variable "min_node_count" {
  description = "The minimum number of nodes in the EKS node group"
  type        = number
  default     = 5
}