output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.mogambo_catalogue_db.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.mogambo_catalogue_db.arn
}

output "db_endpoint" {
  description = "RDS endpoint (hostname)"
  value       = aws_db_instance.mogambo_catalogue_db.endpoint
}

output "db_address" {
  description = "RDS address"
  value       = aws_db_instance.mogambo_catalogue_db.address
}

output "db_port" {
  description = "RDS port"
  value       = aws_db_instance.mogambo_catalogue_db.port
}

output "db_identifier" {
  description = "RDS instance identifier"
  value       = aws_db_instance.mogambo_catalogue_db.identifier
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.mogambo_catalogue_db.db_name
}

output "db_subnet_group_name" {
  description = "DB subnet group name"
  value       = aws_db_subnet_group.mogambo_catalogue_db_subnet_group.name
}

output "db_security_group_ids" {
  description = "Security group IDs attached to RDS"
  value       = aws_db_instance.mogambo_catalogue_db.vpc_security_group_ids
}