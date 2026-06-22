variables {
  site_domain      = "example.com"
  recipient_email  = "owner@example.com"
  sender_email     = "noreply@example.com"
  ses_identity_arn = "arn:aws:ses:ap-southeast-2:123456789012:identity/example.com"
  common_tags      = {}
}

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

run "creates_lambda_function" {
  command = plan

  assert {
    condition     = aws_lambda_function.this.function_name == "contact-example-com"
    error_message = "module must create exactly one Lambda function"
  }
}

run "creates_function_url" {
  command = plan

  assert {
    condition     = aws_lambda_function_url.this.authorization_type == "NONE"
    error_message = "module must create exactly one Function URL"
  }
}

run "function_url_cors_locked_to_site" {
  command = plan

  assert {
    condition     = contains(aws_lambda_function_url.this.cors[0].allow_origins, "https://example.com")
    error_message = "Function URL CORS must allow only the site domain"
  }
}

run "iam_permission_for_function_url" {
  command = plan

  assert {
    condition     = aws_lambda_permission.invoke_via_function_url.action == "lambda:InvokeFunction"
    error_message = "must grant lambda:InvokeFunction for Function URL access"
  }

  assert {
    condition     = aws_lambda_permission.invoke_via_function_url.principal == "*"
    error_message = "Function URL is public, so principal must be '*'"
  }
}

run "dynamodb_table_has_range_key_timestamp" {
  command = plan

  variables {
    enable_submission_log = true
  }

  assert {
    condition     = contains([for a in aws_dynamodb_table.submissions[0].attribute : a.name], "timestamp")
    error_message = "DynamoDB table must have 'timestamp' attribute (used as range key)"
  }
}
