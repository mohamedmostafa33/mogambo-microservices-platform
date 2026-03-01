resource "aws_docdb_subnet_group" "mogambo_documentdb_subnet_group" {
  name        = var.docdb_subnet_group_name
  description = "Subnet group for the Mogambo DocumentDB cluster"
  subnet_ids  = var.docdb_subnet_ids
}

resource "aws_docdb_cluster" "mogambo_carts_db_cluster" {
  cluster_identifier     = var.docdb_identifier
  engine                 = var.docdb_engine
  engine_version         = var.docdb_engine_version
  master_username        = var.docdb_username
  master_password        = var.docdb_password
  db_subnet_group_name   = aws_docdb_subnet_group.mogambo_documentdb_subnet_group.name
  vpc_security_group_ids = [var.docdb_security_group_id]
  skip_final_snapshot    = true
}

resource "aws_docdb_cluster_instance" "mogambo_carts_db_cluster_instance" {
  identifier         = "${var.docdb_identifier}-instance-1"
  cluster_identifier = aws_docdb_cluster.mogambo_carts_db_cluster.id
  instance_class     = var.docdb_instance_class
}