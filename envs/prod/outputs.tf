output "sites" {
  description = "Per-site deployment information"
  value = {
    for k, site in module.static_site : k => {
      domain                 = var.sites[k].domain
      bucket_name            = site.bucket_name
      distribution_id        = site.distribution_id
      distribution_domain    = site.distribution_domain_name
      acm_validation_records = site.acm_validation_records
    }
  }
}

output "contact_forms" {
  description = "Per-site contact form endpoints"
  value = {
    for k, form in module.contact_form : k => {
      function_url   = form.function_url
      log_group      = form.log_group_name
      dynamodb_table = form.dynamodb_table_name
    }
  }
}

output "ses_dkim_records" {
  description = "DKIM CNAME records to add at your registrar for SES domain verification"
  value = [
    for token in aws_ses_domain_dkim.this.dkim_tokens : {
      record_name  = "${token}._domainkey.${var.primary_domain}"
      record_type  = "CNAME"
      record_value = "${token}.dkim.amazonses.com"
    }
  ]
}

output "ses_verification_domain" {
  description = "SES domain identity (verify in SES console)"
  value       = aws_ses_domain_identity.this.domain
}

output "alerts_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "ops_dashboard_name" {
  description = "CloudWatch operations dashboard name (empty if disabled)"
  value       = var.enable_ops_dashboard ? aws_cloudwatch_dashboard.ops[0].dashboard_name : ""
}

output "monthly_budget_name" {
  description = "AWS Budget name (empty if disabled)"
  value       = var.enable_cost_budget ? aws_budgets_budget.monthly[0].name : ""
}

output "team_iam_groups" {
  description = "IAM group names"
  value       = module.team_iam.group_names
}

output "github_infra_role_arn" {
  description = "GitHub Actions infra role ARN for terraform plan/apply (env-specific)"
  value       = module.team_iam.github_infra_role_arn
}

output "github_content_role_arn" {
  description = "GitHub Actions content role ARN for content deploy (env-specific)"
  value       = module.team_iam.github_content_role_arn
}

output "next_steps" {
  description = "Manual steps required after apply"
  value       = <<-EOT
    1. Add ACM validation CNAMEs at your registrar (see 'sites' output)
    2. Add DKIM CNAMEs at your registrar (see 'ses_dkim_records' output)
    3. Add site CNAMEs: <domain> → <distribution_domain>
    4. Confirm SNS alert email subscription (check inbox)
    5. Request SES production access in ${var.aws_region} (if not done)
    6. Deploy content: ../../scripts/deploy-site.sh prod <site-key>
  EOT
}
