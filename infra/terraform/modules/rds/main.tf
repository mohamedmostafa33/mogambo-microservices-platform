resource "aws_db_subnet_group" "mogambo_catalogue_db_subnet_group" {
  name        = var.db_subnet_group_name
  description = "Subnet group for the Mogambo Catalogue database"
  subnet_ids  = var.db_subnet_ids
}

resource "aws_db_instance" "mogambo_catalogue_db" {
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.mogambo_catalogue_db_subnet_group.name
  vpc_security_group_ids = var.db_security_group_ids
  skip_final_snapshot    = true
  multi_az               = false
  publicly_accessible    = false
}