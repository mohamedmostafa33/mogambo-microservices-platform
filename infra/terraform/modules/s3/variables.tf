variable "bucket_name" {
  description = "The name of the S3 bucket to create"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cloudfront_price_class" {
  description = "CloudFront distribution price class (PriceClass_100 = US/EU/Asia, PriceClass_200 = more, PriceClass_All = global)"
  type        = string
}

variable "s3_cors_allowed_origins" {
  description = "Allowed origins for S3 CORS GET/HEAD requests. For production, set this to your frontend domain(s)."
  type        = list(string)
}