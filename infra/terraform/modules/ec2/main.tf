resource "aws_instance" "mogambo_sonarqube_instance" {
  ami                         = var.sonarqube_ami_id
  instance_type               = var.sonarqube_instance_type
  subnet_id                   = var.sonarqube_subnet_id
  vpc_security_group_ids      = [var.sonarqube_security_group_id]
  key_name                    = var.sonarqube_key_name
  associate_public_ip_address = true

  tags = {
    Name = var.sonarqube_instance_name
  }
}