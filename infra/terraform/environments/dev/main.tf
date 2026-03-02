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
  source = "../../modules/ecr"
  frontend_repository_name   = var.frontend_repository_name
  catalogue_repository_name  = var.catalogue_repository_name
  cart_repository_name       = var.cart_repository_name
}