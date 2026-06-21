data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "${replace(var.domain, ".", "-")}-${local.account_id}"
  aliases     = var.enable_www_redirect ? [var.domain, "www.${var.domain}"] : [var.domain]
  site_tags   = merge(var.common_tags, { Site = var.domain })
}

# --------------------------------------------------------------------------
# S3 Origin Bucket (private — served only via CloudFront OAC)
# --------------------------------------------------------------------------
resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name

  tags = local.site_tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# --------------------------------------------------------------------------
# CloudFront Origin Access Control (OAC)
# --------------------------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.domain
  description                       = "OAC for ${var.domain}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy — allow only this distribution via OAC
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontOAC"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.this.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
}

# --------------------------------------------------------------------------
# ACM Certificate (must be in us-east-1 for CloudFront)
# --------------------------------------------------------------------------
resource "aws_acm_certificate" "this" {
  provider                  = aws.us_east_1
  domain_name               = var.domain
  subject_alternative_names = var.enable_www_redirect ? ["www.${var.domain}"] : []
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.site_tags
}

resource "aws_acm_certificate_validation" "this" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.this.arn

  timeouts {
    create = "45m"
  }
}

# --------------------------------------------------------------------------
# CloudFront Function — www to apex redirect (ES5.1 for CloudFront runtime)
# --------------------------------------------------------------------------
resource "aws_cloudfront_function" "www_redirect" {
  count   = var.enable_www_redirect ? 1 : 0
  name    = "www-redirect-${replace(var.domain, ".", "-")}"
  runtime = "cloudfront-js-1.0"
  comment = "Redirect www.${var.domain} to ${var.domain}"
  publish = true

  code = <<-JS
    function handler(event) {
      var request = event.request;
      var host = request.headers.host.value;
      if (host.substring(0, 4) === 'www.') {
        return {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            location: { value: 'https://' + host.substring(4) + request.uri }
          }
        };
      }
      return request;
    }
  JS
}

# --------------------------------------------------------------------------
# CloudFront Distribution
# --------------------------------------------------------------------------
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Static site for ${var.domain}"
  default_root_object = "index.html"
  price_class         = var.price_class
  aliases             = local.aliases
  wait_for_deployment = false

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = "s3-${local.bucket_name}"
  }

  default_cache_behavior {
    target_origin_id       = "s3-${local.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    dynamic "function_association" {
      for_each = var.enable_www_redirect ? [1] : []
      content {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.www_redirect[0].arn
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 30
  }

  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 30
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = local.site_tags
}
