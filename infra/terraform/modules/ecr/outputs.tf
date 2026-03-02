output "frontend_repository_name" {
  description = "Name of the frontend ECR repository"
  value       = aws_ecr_repository.mogambo_frontend_repository.name
}

output "frontend_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = aws_ecr_repository.mogambo_frontend_repository.repository_url
}

output "frontend_repository_arn" {
  description = "ARN of the frontend ECR repository"
  value       = aws_ecr_repository.mogambo_frontend_repository.arn
}

output "catalogue_repository_name" {
  description = "Name of the catalogue ECR repository"
  value       = aws_ecr_repository.mogambo_catalogue_repository.name
}

output "catalogue_repository_url" {
  description = "URL of the catalogue ECR repository"
  value       = aws_ecr_repository.mogambo_catalogue_repository.repository_url
}

output "catalogue_repository_arn" {
  description = "ARN of the catalogue ECR repository"
  value       = aws_ecr_repository.mogambo_catalogue_repository.arn
}

output "cart_repository_name" {
  description = "Name of the cart ECR repository"
  value       = aws_ecr_repository.mogambo_cart_repository.name
}

output "cart_repository_url" {
  description = "URL of the cart ECR repository"
  value       = aws_ecr_repository.mogambo_cart_repository.repository_url
}

output "cart_repository_arn" {
  description = "ARN of the cart ECR repository"
  value       = aws_ecr_repository.mogambo_cart_repository.arn
}