data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "mogambo_s3_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "mogambo_s3_account_public_access_block" {
  bucket                  = aws_s3_bucket.mogambo_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "mogambo_s3_bucket_versioning" {
  bucket = aws_s3_bucket.mogambo_s3_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mogambo_s3_bucket_sse" {
  bucket = aws_s3_bucket.mogambo_s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "mogambo_s3_bucket_cors" {
  bucket = aws_s3_bucket.mogambo_s3_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.s3_cors_allowed_origins
    max_age_seconds = 3600
  }
}

resource "aws_cloudfront_origin_access_control" "mogambo_oac" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for Mogambo S3 static and media assets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "mogambo_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Mogambo static and media assets CDN"
  default_root_object = "index.html"
  price_class         = var.cloudfront_price_class

  origin {
    domain_name              = aws_s3_bucket.mogambo_s3_bucket.bucket_regional_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.mogambo_oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.bucket_name}-cdn"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_policy" "mogambo_s3_bucket_policy" {
  bucket = aws_s3_bucket.mogambo_s3_bucket.id

  depends_on = [aws_s3_bucket_public_access_block.mogambo_s3_account_public_access_block]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.mogambo_s3_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.mogambo_distribution.id}"
          }
        }
      }
    ]
  })
}