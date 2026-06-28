output "function_url" {
  description = "Lambda Function URL endpoint (POST form submissions here)"
  value       = aws_lambda_function_url.this.function_url
}

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "log_group_name" {
  description = "CloudWatch log group for the Lambda function"
  value       = aws_cloudwatch_log_group.this.name
}

output "dynamodb_table_name" {
  description = "DynamoDB table for submission logs (empty if disabled)"
  value       = var.enable_submission_log ? aws_dynamodb_table.submissions[0].name : ""
}

output "role_arn" {
  description = "IAM role ARN for the Lambda function"
  value       = aws_iam_role.this.arn
}
