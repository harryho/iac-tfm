# contact-form

Lambda + SES + DynamoDB contact form handler for a single site. Public
Function URL, CORS locked to the site domain. Optional Cloudflare
Turnstile captcha.

## Usage

```hcl
module "form" {
  source = "../../modules/contact-form"

  site_domain          = "example.com"
  recipient_email      = "owner@example.com"
  sender_email         = "noreply@example.com"
  ses_identity_arn     = aws_ses_domain_identity.this.arn
  turnstile_secret     = var.turnstile_secret
  enable_submission_log = true
  alert_topic_arn      = aws_sns_topic.alerts.arn
  common_tags          = local.common_tags
}
```

## Lambda source

`src/index.mjs` — Node.js 20, ESM. Bundled at apply time via the
`archive_file` data source.

## Inputs

See `variables.tf`. The `enable_contact_form` flag is set per site in
`envs/<env>/terraform.tfvars`'s `sites` map. The per-site files in
`envs/<env>/sites/_<site>.tf` are documentation placeholders — config
lives in tfvars, the file just reminds you to drop the underscore
prefix when you're ready.

## Outputs

| Output | Description |
|---|---|
| `function_url` | POST endpoint for form submissions |
| `function_name` | Lambda function name |
| `log_group_name` | CloudWatch log group |
| `dynamodb_table_name` | Submission log table (empty if disabled) |
| `role_arn` | Lambda IAM role ARN |
