module "vpc" {
  source                      = "../../modules/vpc"
  vpc_cidr_block              = var.vpc_cidr_block
  public_subnet_cidr_block_1  = var.public_subnet_cidr_block_1
  public_subnet_cidr_block_2  = var.public_subnet_cidr_block_2
  private_subnet_cidr_block_1 = var.private_subnet_cidr_block_1
  private_subnet_cidr_block_2 = var.private_subnet_cidr_block_2
}

module "sg" {
  source = "../../modules/sg"
  vpc_id = module.vpc.vpc_id
}

module "ec2" {
  source                      = "../../modules/ec2"
  sonarqube_ami_id            = var.sonarqube_ami_id
  sonarqube_instance_type     = var.sonarqube_instance_type
  sonarqube_subnet_id         = module.vpc.public_subnet_ids[0]
  sonarqube_security_group_id = module.sg.sonarqube_sg_id
  sonarqube_key_name          = var.sonarqube_key_name
  sonarqube_instance_name     = var.sonarqube_instance_name
}

module "rds" {
  source                   = "../../modules/rds"
  db_subnet_group_name     = var.db_subnet_group_name
  db_subnet_ids            = module.vpc.private_subnet_ids
  db_engine                = var.db_engine
  db_engine_version        = var.db_engine_version
  db_instance_class        = var.db_instance_class
  db_allocated_storage     = var.db_allocated_storage
  db_max_allocated_storage = var.db_max_allocated_storage
  db_identifier            = var.db_identifier
  db_name                  = var.db_name
  db_username              = var.db_username
  db_password              = var.db_password
  db_security_group_ids    = [module.sg.catalogue_db_sg_id]
}

module "ecr" {
  source                    = "../../modules/ecr"
  frontend_repository_name  = var.frontend_repository_name
  catalogue_repository_name = var.catalogue_repository_name
  cart_repository_name      = var.cart_repository_name
}

module "s3" {
  source                  = "../../modules/s3"
  bucket_name             = var.bucket_name
  environment             = var.environment
  cloudfront_price_class  = var.cloudfront_price_class
  s3_cors_allowed_origins = var.s3_cors_allowed_origins
}

module "iam" {
  source                   = "../../modules/iam"
  eks_role_name            = var.eks_role_name
  eks_node_group_role_name = var.eks_node_group_role_name
}

module "eks" {
  source                       = "../../modules/eks"
  cluster_name                 = var.cluster_name
  kubernetes_version           = var.kubernetes_version
  eks_role_arn                 = module.iam.eks_cluster_role_arn
  eks_subnet_ids               = module.vpc.private_subnet_ids
  eks_node_group_name          = var.eks_node_group_name
  eks_node_group_role_arn      = module.iam.eks_node_group_role_arn
  eks_node_group_instance_type = var.eks_node_group_instance_type
  desired_node_count           = var.desired_node_count
  max_node_count               = var.max_node_count
  min_node_count               = var.min_node_count
}