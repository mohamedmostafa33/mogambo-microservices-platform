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