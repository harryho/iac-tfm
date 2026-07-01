output "notification_channel_id" {
  description = "ID of the email notification channel for alerts"
  value       = var.enable_budget ? google_monitoring_notification_channel.email[0].name : ""
}

output "budget_id" {
  description = "ID of the billing budget (empty if budget disabled)"
  value       = var.enable_budget && var.billing_account_id != "" ? google_billing_budget.monthly[0].id : ""
  sensitive   = true
}

output "dashboard_id" {
  description = "ID of the Cloud Monitoring dashboard (empty if dashboard disabled)"
  value       = var.enable_dashboard ? google_monitoring_dashboard.ops[0].id : ""
}