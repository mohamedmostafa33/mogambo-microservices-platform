output "docdb_cluster_endpoint" {
  description = "The writer endpoint of the DocumentDB cluster"
  value       = aws_docdb_cluster.mogambo_carts_db_cluster.endpoint
}

output "docdb_cluster_reader_endpoint" {
  description = "The reader endpoint of the DocumentDB cluster"
  value       = aws_docdb_cluster.mogambo_carts_db_cluster.reader_endpoint
}

output "docdb_cluster_id" {
  description = "The ID of the DocumentDB cluster"
  value       = aws_docdb_cluster.mogambo_carts_db_cluster.id
}

output "docdb_instance_ids" {
  description = "List of all DocumentDB cluster instance IDs"
  value       = [
    aws_docdb_cluster_instance.mogambo_carts_db_cluster_instance.id
  ]
}

output "docdb_instance_endpoints" {
  description = "List of endpoints for each DocumentDB instance"
  value = [
    aws_docdb_cluster_instance.mogambo_carts_db_cluster_instance.endpoint
  ]
}