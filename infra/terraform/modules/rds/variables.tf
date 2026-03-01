variable "db_subnet_group_name" {
  description = "The name of the DB subnet group to associate with the RDS instance"
  type        = string
}

variable "db_subnet_ids" {
  description = "List of subnet IDs to associate with the DB subnet group"
  type        = list(string)
}

variable "db_engine" {
  description = "The Engine type for the RDS instance"
  type        = string
}

variable "db_engine_version" {
  description = "The Engine version for the RDS instance"
  type        = string
}

variable "db_instance_class" {
  description = "The instance class for the RDS instance"
  type        = string
}

variable "db_allocated_storage" {
  description = "Allocated storage for the RDS instance"
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for the RDS instance"
  type        = number
}

variable "db_identifier" {
  description = "The identifier for the RDS instance"
  type        = string
}

variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
}

variable "db_username" {
  description = "The master username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "The master password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "db_security_group_ids" {
  description = "List of security group IDs to associate with the RDS instance"
  type        = list(string)
}