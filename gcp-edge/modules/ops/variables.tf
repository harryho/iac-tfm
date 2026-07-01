variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region (for dashboard display preferences)"
  type        = string
  default     = "us-central1"
}

variable "alert_email" {
  description = "Email address for budget and monitoring alerts"
  type        = string
}

variable "billing_account_id" {
  description = "Billing account ID (e.g. XXXXXX-YYYYYY-ZZZZZZ). Leave empty to skip budget creation."
  type        = string
  default     = ""
  sensitive   = true
}

variable "monthly_budget_limit_usd" {
  description = "Monthly cost budget limit in USD"
  type        = number
  default     = 5
}

variable "enable_budget" {
  description = "Create the billing budget with email alerts"
  type        = bool
  default     = true
}

variable "enable_dashboard" {
  description = "Create the Cloud Monitoring dashboard"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project name used for resource naming and label filters"
  type        = string
  default     = "gcp-edge"
}

variable "environment" {
  description = "Environment name (used in resource naming)"
  type        = string
}

variable "common_labels" {
  description = "Labels applied to all resources"
  type        = map(string)
  default     = {}
}