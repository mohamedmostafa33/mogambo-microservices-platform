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

variable "docdb_subnet_group_name" {
  description = "The name of the subnet group for the DocumentDB cluster"
  type        = string
  default     = "mogambo-docdb-subnet-group"
}

variable "docdb_identifier" {
  description = "The DocumentDB cluster identifier"
  type        = string
  default     = "mogambo-carts-docdb-cluster"
}

variable "docdb_engine" {
  description = "The DocumentDB engine"
  type        = string
  default     = "docdb"
}

variable "docdb_engine_version" {
  description = "The DocumentDB engine version"
  type        = string
  default     = "5.0.0"
}

variable "docdb_username" {
  description = "The DocumentDB master username"
  type        = string
  default     = "mogambo_user"
}

variable "docdb_password" {
  description = "The DocumentDB master password"
  type        = string
  sensitive   = true
  default     = "Mogambo#2026!"
}

variable "docdb_instance_class" {
  description = "The instance class for the DocumentDB cluster"
  type        = string
  default     = "db.t3.medium"
}