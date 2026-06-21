# --------------------------------------------------------------------------
# SES domain identity — one per project (covers all subdomains)
# --------------------------------------------------------------------------
resource "aws_ses_domain_identity" "this" {
  domain = var.primary_domain
}

resource "aws_ses_domain_dkim" "this" {
  domain = aws_ses_domain_identity.this.domain
}

# --------------------------------------------------------------------------
# SNS alerts topic — for Lambda error alarms
# --------------------------------------------------------------------------
resource "aws_sns_topic" "alerts" {
  name              = "${var.project_name}-alerts"
  display_name      = "${var.project_name} Alerts"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  dashboard_cloudfront_request_metrics = [
    for _, site in module.static_site : [
      "AWS/CloudFront",
      "Requests",
      "DistributionId",
      site.distribution_id,
      "Region",
      "Global"
    ]
  ]

  dashboard_lambda_error_metrics = [
    for _, form in module.contact_form : [
      "AWS/Lambda",
      "Errors",
      "FunctionName",
      form.function_name
    ]
  ]

  dashboard_dynamodb_write_metrics = [
    for _, form in module.contact_form : [
      "AWS/DynamoDB",
      "ConsumedWriteCapacityUnits",
      "TableName",
      form.dynamodb_table_name
    ]
  ]
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowBudgetsToPublish"
        Effect    = "Allow"
        Principal = { Service = "budgets.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.alerts.arn
      }
    ]
  })
}

resource "aws_budgets_budget" "monthly" {
  count = var.enable_cost_budget ? 1 : 0

  name         = "${var.project_name}-monthly-cost"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("Project$%s", var.project_name)]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  depends_on = [aws_sns_topic_policy.alerts]
}

resource "aws_cloudwatch_dashboard" "ops" {
  count = var.enable_ops_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-ops"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "CloudFront Requests (sum)"
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          view    = "timeSeries"
          metrics = local.dashboard_cloudfront_request_metrics
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Errors (sum)"
          region  = var.aws_region
          stat    = "Sum"
          period  = 300
          view    = "timeSeries"
          metrics = local.dashboard_lambda_error_metrics
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "DynamoDB Consumed Write Capacity (sum)"
          region  = var.aws_region
          stat    = "Sum"
          period  = 300
          view    = "timeSeries"
          metrics = local.dashboard_dynamodb_write_metrics
        }
      },
      {
        type   = "text"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          markdown = "# ${var.project_name} ops\n- Monthly budget USD: ${var.monthly_budget_limit_usd}\n- Alerts topic: ${aws_sns_topic.alerts.arn}\n- Region: ${var.aws_region}"
        }
      }
    ]
  })
}
