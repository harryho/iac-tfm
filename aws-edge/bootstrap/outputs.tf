output "backend_config" {
  description = "Backend configuration to use in envs/<env>/main.tf"
  value = {
    bucket         = aws_s3_bucket.terraform_state.id
    region         = local.region
    dynamodb_table = aws_dynamodb_table.terraform_locks.id
    encrypt        = true
  }
}

output "state_bucket_name" {
  description = "Name of the S3 state bucket"
  value       = aws_s3_bucket.terraform_state.id
}
