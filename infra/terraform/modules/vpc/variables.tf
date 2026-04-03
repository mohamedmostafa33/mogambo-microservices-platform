variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr_block_1" {
  description = "CIDR block for the public subnet 1"
  type        = string
}

variable "public_subnet_cidr_block_2" {
  description = "CIDR block for the public subnet 2"
  type        = string
}

variable "private_subnet_cidr_block_1" {
  description = "CIDR block for the private subnet 1"
  type        = string
}

variable "private_subnet_cidr_block_2" {
  description = "CIDR block for the private subnet 2"
  type        = string
}