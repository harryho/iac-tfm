data "aws_caller_identity" "current" {}

locals {
  function_name = "contact-${replace(var.site_domain, ".", "-")}"
  site_tags     = merge(var.common_tags, { Site = var.site_domain })
}

# --------------------------------------------------------------------------
# DynamoDB table for submission logging (optional)
# --------------------------------------------------------------------------
resource "aws_dynamodb_table" "submissions" {
  count        = var.enable_submission_log ? 1 : 0
  name         = "contact-submissions-${replace(var.site_domain, ".", "-")}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "site_domain"
  range_key    = "timestamp"

  attribute {
    name = "site_domain"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = local.site_tags
}

# --------------------------------------------------------------------------
# CloudWatch Log Group
# --------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days

  tags = local.site_tags
}

# --------------------------------------------------------------------------
# IAM Role — least privilege: SES send + DynamoDB put + CloudWatch logs
# --------------------------------------------------------------------------
resource "aws_iam_role" "this" {
  name = "${local.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.site_tags
}

resource "aws_iam_role_policy" "ses" {
  name = "ses-send"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = var.ses_identity_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "dynamodb" {
  count = var.enable_submission_log ? 1 : 0
  name  = "dynamodb-put"
  role  = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.submissions[0].arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.this.arn}:*"
      }
    ]
  })
}

# --------------------------------------------------------------------------
# Lambda Function
# --------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/builds/${local.function_name}.zip"
}

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = "Contact form handler for ${var.site_domain}"
  role          = aws_iam_role.this.arn
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  memory_size   = 128
  timeout       = 5

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SITE_DOMAIN      = var.site_domain
      RECIPIENT_EMAIL  = var.recipient_email
      SENDER_EMAIL     = var.sender_email
      TURNSTILE_SECRET = var.turnstile_secret
      DYNAMODB_TABLE   = var.enable_submission_log ? aws_dynamodb_table.submissions[0].name : ""
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = local.site_tags
}

# --------------------------------------------------------------------------
# Lambda Function URL (public endpoint, CORS locked to site domain)
# --------------------------------------------------------------------------
resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["https://${var.site_domain}"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
  }
}

resource "aws_lambda_permission" "invoke_via_function_url" {
  statement_id  = "AllowInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "*"
}

# --------------------------------------------------------------------------
# CloudWatch Alarm — error rate
# --------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "errors" {
  count = var.enable_error_alarm ? 1 : 0

  alarm_name          = "${local.function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Contact form Lambda errors for ${var.site_domain}"
  alarm_actions       = [var.alert_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }

  tags = local.site_tags
}
