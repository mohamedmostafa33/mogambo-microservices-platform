variable "sonarqube_ami_id" {
  description = "AMI ID for the SonarQube instance"
  type        = string
}

variable "sonarqube_instance_type" {
  description = "Instance type for the SonarQube instance"
  type        = string
}

variable "sonarqube_subnet_id" {
  description = "Subnet ID for the SonarQube instance"
  type        = string
}

variable "sonarqube_security_group_id" {
  description = "Security group ID for the SonarQube instance"
  type        = string
}

variable "sonarqube_key_name" {
  description = "Key pair name for the SonarQube instance"
  type        = string
}

variable "sonarqube_instance_name" {
  description = "Name for the SonarQube instance"
  type        = string
}
