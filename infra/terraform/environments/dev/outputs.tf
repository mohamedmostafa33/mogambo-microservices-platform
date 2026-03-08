output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [
    module.vpc.public_subnet_ids[0],
    module.vpc.public_subnet_ids[1]
  ]
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = [
    module.vpc.public_subnet_cidrs[0],
    module.vpc.public_subnet_cidrs[1]
  ]
}

output "public_subnet_azs" {
  description = "Availability Zones of the public subnets"
  value       = [
    module.vpc.public_subnet_azs[0],
    module.vpc.public_subnet_azs[1]
  ]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [
    module.vpc.private_subnet_ids[0],
    module.vpc.private_subnet_ids[1]
  ]
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = [
    module.vpc.private_subnet_cidrs[0],
    module.vpc.private_subnet_cidrs[1]
  ]
}

output "private_subnet_azs" {
  description = "Availability Zones of the private subnets"
  value       = [
    module.vpc.private_subnet_azs[0],
    module.vpc.private_subnet_azs[1]
  ]
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = module.vpc.nat_gateway_id
}

output "nat_gateway_eip" {
  description = "The Elastic IP associated with the NAT Gateway"
  value       = module.vpc.nat_gateway_eip
}

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = module.vpc.public_route_table_id
}

output "private_route_table_id" {
  description = "The ID of the private route table"
  value       = module.vpc.private_route_table_id
}

output "alb_sg_id" {
  description = "Security Group ID for the Application Load Balancer"
  value       = module.sg.alb_sg_id
}

output "eks_node_group_sg_id" {
  description = "Security Group ID for the EKS Node Group"
  value       = module.sg.eks_node_group_sg_id
}

output "catalogue_db_sg_id" {
  description = "Security Group ID for the Catalogue Database (RDS)"
  value       = module.sg.catalogue_db_sg_id
}

output "db_instance_id" {
  description = "RDS instance ID"
  value       = module.rds.db_instance_id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = module.rds.db_instance_arn
}

output "db_endpoint" {
  description = "RDS endpoint (hostname)"
  value       = module.rds.db_endpoint
}

output "db_address" {
  description = "RDS address"
  value       = module.rds.db_address
}

output "db_port" {
  description = "RDS port"
  value       = module.rds.db_port
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = module.rds.db_identifier
}

output "db_name" {
  description = "Database name"
  value       = module.rds.db_name
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = module.rds.db_subnet_group_name
}

output "db_security_group_ids" {
  description = "Security group IDs attached to RDS"
  value       = module.rds.db_security_group_ids
}

output "frontend_repository_name" {
  description = "Name of the frontend ECR repository"
  value       = module.ecr.frontend_repository_name
}

output "frontend_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = module.ecr.frontend_repository_url
}

output "frontend_repository_arn" {
  description = "ARN of the frontend ECR repository"
  value       = module.ecr.frontend_repository_arn
}

output "catalogue_repository_name" {
  description = "Name of the catalogue ECR repository"
  value       = module.ecr.catalogue_repository_name
}

output "catalogue_repository_url" {
  description = "URL of the catalogue ECR repository"
  value       = module.ecr.catalogue_repository_url
}

output "catalogue_repository_arn" {
  description = "ARN of the catalogue ECR repository"
  value       = module.ecr.catalogue_repository_arn
}

output "cart_repository_name" {
  description = "Name of the cart ECR repository"
  value       = module.ecr.cart_repository_name
}

output "cart_repository_url" {
  description = "URL of the cart ECR repository"
  value       = module.ecr.cart_repository_url
}

output "cart_repository_arn" {
  description = "ARN of the cart ECR repository"
  value       = module.ecr.cart_repository_arn
}

output "mogambo_s3_bucket_name" {
  description = "Name of the Mogambo S3 bucket"
  value       = module.s3.mogambo_s3_bucket_name
}

output "mogambo_s3_bucket_arn" {
  description = "ARN of the Mogambo S3 bucket"
  value       = module.s3.mogambo_s3_bucket_arn
}

output "mogambo_s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = module.s3.mogambo_s3_bucket_regional_domain_name
}

output "mogambo_s3_bucket_region" {
  description = "Region where the S3 bucket is created"
  value       = module.s3.mogambo_s3_bucket_region
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name for accessing static and media assets"
  value       = module.s3.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.s3.cloudfront_distribution_id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = module.s3.cloudfront_distribution_arn
}

output "eks_cluster_role_name" {
  description = "The name of the IAM role for the EKS cluster"
  value       = module.iam.eks_cluster_role_name
}

output "eks_cluster_role_arn" {
  description = "The ARN of the IAM role for the EKS cluster"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_group_role_name" {
  description = "The name of the IAM role for the EKS node group"
  value       = module.iam.eks_node_group_role_name
}

output "eks_node_group_role_arn" {
  description = "The ARN of the IAM role for the EKS node group"
  value       = module.iam.eks_node_group_role_arn
}

output "eks_node_group_policies" {
  description = "List of attached IAM policies for the node group role"
  value       = module.iam.eks_node_group_policies
}

output "eks_cluster_policies" {
  description = "List of attached IAM policies for the cluster role"
  value       = module.iam.eks_cluster_policies
}

output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.eks_cluster_name
}

output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = module.eks.eks_cluster_arn
}

output "eks_cluster_endpoint" {
  description = "The API server endpoint of the EKS cluster"
  value       = module.eks.eks_cluster_endpoint
}

output "eks_node_group_name" {
  description = "The name of the EKS node group"
  value       = module.eks.eks_node_group_name
}

output "eks_node_group_arn" {
  description = "The ARN of the EKS node group"
  value       = module.eks.eks_node_group_arn
}

output "sonarqube_sg_id" {
  description = "Security Group ID for the SonarQube EC2 instance"
  value       = module.sg.sonarqube_sg_id
}

output "sonarqube_public_ip" {
  description = "The public IP of the SonarQube EC2 instance"
  value       = module.ec2.sonarqube_public_ip
}

output "sonarqube_instance_id" {
  description = "The ID of the SonarQube EC2 instance"
  value       = module.ec2.sonarqube_instance_id
}

output "sonarqube_private_ip" {
  description = "The private IP of the SonarQube EC2 instance"
  value       = module.ec2.sonarqube_private_ip
}

output "sonarqube_public_dns" {
  description = "The public DNS of the SonarQube EC2 instance"
  value       = module.ec2.sonarqube_public_dns
}