provider "aws" {
  region = "us-east-1"  # Change this to your desired region
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

variable "environments" {
  description = "List of environment names"
  type        = list(string)
}

resource "aws_s3_bucket_object" "website_objects" {
  for_each = toset(var.environments)

  bucket = var.website_bucket
  key    = each.value

  source = each.value
}

resource "aws_cloudfront_distribution" "website_distribution" {
  count = length(var.environments)

  origin {
    domain_name = aws_s3_bucket_object.website_objects[var.environments[count.index]].bucket
    origin_id   = var.environments[count.index]
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.environments[count.index]
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "environment_endpoints" {
  value = { for env in var.environments :
    env => aws_cloudfront_distribution.website_distribution[env].domain_name
  }
}
