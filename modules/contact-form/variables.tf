terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

variable "site_domain" {
  description = "Domain name of the site this form serves (e.g. example.com)"
  type        = string
}

variable "recipient_email" {
  description = "Email address to receive form submissions"
  type        = string
}

variable "sender_email" {
  description = "From address for SES (e.g. noreply@example.com)"
  type        = string
}

variable "ses_identity_arn" {
  description = "ARN of the verified SES domain identity (created at root level)"
  type        = string
}

variable "turnstile_secret" {
  description = "Cloudflare Turnstile secret key (leave empty to skip captcha)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_submission_log" {
  description = "Store form submissions in DynamoDB for audit"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 30
}

variable "alert_topic_arn" {
  description = "SNS topic ARN for Lambda error alarms (leave empty to skip alarm)"
  type        = string
  default     = ""
}

variable "enable_error_alarm" {
  description = "Create CloudWatch alarm for Lambda errors"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}
