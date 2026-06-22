variables {
  domain              = "example.com"
  enable_www_redirect = true
  price_class         = "PriceClass_100"
  common_tags         = {}
}

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "ap-southeast-2"
    }
  }
}

mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }
}

run "cloudfront_enabled" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.enabled == true
    error_message = "cloudfront enabled"
  }
}

run "s3_bucket_named" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "example-com-123456789012"
    error_message = "s3 bucket name"
  }
}

run "acm_domain" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.domain_name == "example.com"
    error_message = "acm domain"
  }
}

run "s3_bucket_blocks_public_access" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "block_public_acls"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "restrict_public_buckets"
  }
}

run "oac_signing_behavior_always" {
  command = plan

  assert {
    condition     = aws_cloudfront_origin_access_control.this.signing_behavior == "always"
    error_message = "signing_behavior"
  }
}
