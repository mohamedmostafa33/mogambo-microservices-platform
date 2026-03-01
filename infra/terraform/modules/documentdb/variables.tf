variable "docdb_subnet_group_name" {
  description = "The name of the subnet group for the DocumentDB cluster"
  type        = string
}

variable "docdb_subnet_ids" {
  description = "The subnet IDs for the DocumentDB cluster"
  type        = list(string)
}

variable "docdb_identifier" {
  description = "The DocumentDB cluster identifier"
  type        = string
}

variable "docdb_engine" {
  description = "The DocumentDB engine"
  type        = string
}

variable "docdb_engine_version" {
  description = "The DocumentDB engine version"
  type        = string
}

variable "docdb_username" {
  description = "The DocumentDB master username"
  type        = string
}

variable "docdb_password" {
  description = "The DocumentDB master password"
  type        = string
  sensitive   = true
}

variable "docdb_security_group_id" {
  description = "The security group ID for the DocumentDB cluster"
  type        = string
}

variable "docdb_instance_class" {
  description = "The instance class for the DocumentDB cluster"
  type        = string
}