output "sonarqube_public_ip" {
  description = "The public IP of the SonarQube EC2 instance"
  value       = aws_instance.mogambo_sonarqube_instance.public_ip
}

output "sonarqube_instance_id" {
  description = "The ID of the SonarQube EC2 instance"
  value       = aws_instance.mogambo_sonarqube_instance.id
}

output "sonarqube_private_ip" {
  description = "The private IP of the SonarQube EC2 instance"
  value       = aws_instance.mogambo_sonarqube_instance.private_ip
}

output "sonarqube_public_dns" {
  description = "The public DNS of the SonarQube EC2 instance"
  value       = aws_instance.mogambo_sonarqube_instance.public_dns
}