provider "aws" {
  region = "us-east-1"  # Change this to your desired region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
variable "aws_access_key" {
  description = "AWS access key ID"
}

variable "aws_secret_key" {
  description = "AWS secret access key"
}

variable "website_bucket" {
  description = "S3 bucket name containing website source code"
}

variable "target_environment" {
  description = "Environment to deploy"
}

resource "aws_s3_object" "website_objects" {
  for_each = fileset("./main", "**/*")

  bucket = var.website_bucket
  key    = "${var.target_environment}/${each.value}"
  source = "./${each.value}"
}

resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = "${var.website_bucket}.s3.amazonaws.com"  # S3 bucket endpoint domain
    origin_id   = var.target_environment
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.target_environment
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  depends_on = [aws_s3_bucket_policy.public_bucket_policy]

}

resource "aws_s3_bucket_policy" "public_bucket_policy" {
  bucket = var.website_bucket

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "PublicReadGetObject",
        Effect = "Allow",
        Principal = "*",
        Action = ["s3:GetObject"],
        Resource = "arn:aws:s3:::${var.website_bucket}/*",
      },
    ],
  })
}

resource "aws_s3_bucket_cors_configuration" "public_cors_rule" {
  bucket = var.website_bucket

  allowed_origins = [aws_cloudfront_distribution.website_distribution.domain_name]
  allowed_methods = ["GET"]
  max_age_seconds = 3600
}

output "environment_endpoints" {
  value = aws_cloudfront_distribution.website_distribution.domain_name
}
