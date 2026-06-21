# static-site

One CloudFront distribution + S3 bucket + ACM certificate (us-east-1) for
a single domain. Private S3, served only via Origin Access Control.

## Usage

```hcl
module "site" {
  source = "../../modules/static-site"

  domain              = "example.com"
  enable_www_redirect = true
  price_class         = "PriceClass_100"
  common_tags         = local.common_tags
}
```

## Inputs

See `variables.tf`.

## Outputs

| Output | Description |
|---|---|
| `bucket_name` | S3 bucket for content |
| `distribution_id` | CloudFront distribution ID |
| `distribution_domain_name` | CNAME target |
| `acm_certificate_arn` | ACM cert (us-east-1) |
| `acm_validation_records` | DNS records to add at registrar |
| `www_redirect_function_name` | CloudFront Function name (empty if redirect disabled) |
