output "bucket_name" {
  description = "S3 bucket name for site content"
  value       = aws_s3_bucket.this.id
}

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain (CNAME target)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "acm_validation_records" {
  description = "DNS CNAME records to add at your registrar for ACM validation"
  value = [
    for dvo in aws_acm_certificate.this.domain_validation_options : {
      domain_name  = dvo.domain_name
      record_name  = trimsuffix(dvo.resource_record_name, ".")
      record_type  = dvo.resource_record_type
      record_value = trimsuffix(dvo.resource_record_value, ".")
    }
  ]
}
