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

output "carts_db_sg_id" {
  description = "Security Group ID for the Carts Database (DocumentDB)"
  value       = module.sg.carts_db_sg_id
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

output "docdb_cluster_endpoint" {
  description = "The writer endpoint of the DocumentDB cluster"
  value       = module.documentdb.docdb_cluster_endpoint
}

output "docdb_cluster_reader_endpoint" {
  description = "The reader endpoint of the DocumentDB cluster"
  value       = module.documentdb.docdb_cluster_reader_endpoint
}

output "docdb_cluster_id" {
  description = "The ID of the DocumentDB cluster"
  value       = module.documentdb.docdb_cluster_id
}

output "docdb_instance_ids" {
  description = "List of all DocumentDB cluster instance IDs"
  value       = [
    module.documentdb.docdb_instance_ids[0]
  ]
}

output "docdb_instance_endpoints" {
  description = "List of endpoints for each DocumentDB instance"
  value = [
    module.documentdb.docdb_instance_endpoints[0]
  ]
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