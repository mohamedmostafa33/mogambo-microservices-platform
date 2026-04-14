output "mogambo_s3_bucket_name" {
  description = "Name of the Mogambo S3 bucket"
  value       = aws_s3_bucket.mogambo_s3_bucket.bucket
}

output "mogambo_s3_bucket_arn" {
  description = "ARN of the Mogambo S3 bucket"
  value       = aws_s3_bucket.mogambo_s3_bucket.arn
}

output "mogambo_s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket (used as CloudFront origin)"
  value       = aws_s3_bucket.mogambo_s3_bucket.bucket_regional_domain_name
}

output "mogambo_s3_bucket_region" {
  description = "Region where the S3 bucket is created"
  value       = aws_s3_bucket.mogambo_s3_bucket.region
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for accessing static and media assets"
  value       = aws_cloudfront_distribution.mogambo_distribution.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.mogambo_distribution.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.mogambo_distribution.arn
}

output "cloudfront_catalogue_images_base_url" {
  description = "Base URL for catalogue images served through CloudFront"
  value       = "https://${aws_cloudfront_distribution.mogambo_distribution.domain_name}/catalogue/images"
}