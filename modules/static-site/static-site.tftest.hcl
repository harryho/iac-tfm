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
}

run "creates_one_cloudfront" {
  command = plan

  assert {
    condition     = aws_cloudfront_distribution.this.enabled == true
    error_message = "module must create exactly one CloudFront distribution"
  }
}

run "creates_one_s3_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket.this.bucket == "example-com-123456789012"
    error_message = "module must create exactly one S3 bucket"
  }
}

run "creates_one_acm_certificate" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.domain_name == "example.com"
    error_message = "module must create exactly one ACM certificate"
  }
}

run "s3_bucket_blocks_public_access" {
  command = plan

  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "S3 bucket must block public ACLs"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "S3 bucket must restrict public buckets"
  }
}

run "oac_signing_behavior_always" {
  command = plan

  assert {
    condition     = aws_cloudfront_origin_access_control.this.signing_behavior == "always"
    error_message = "OAC signing behavior must be 'always'"
  }
}
