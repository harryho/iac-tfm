variable "aws_region" {
  description = "AWS region for all resources (except ACM)"
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = contains(["ap-southeast-2", "ap-southeast-4", "us-east-1"], var.aws_region)
    error_message = "aws_region must be ap-southeast-2, ap-southeast-4, or us-east-1."
  }
}

variable "project_name" {
  description = "Project name used in resource naming and tags"
  type        = string
  default     = "iac-tfm"
}

variable "environment_name" {
  description = "Short env identifier (e.g. prod, stage, dev). Used in state path and the Env tag."
  type        = string
  default     = "prod"
}

variable "role_name_prefix" {
  description = "Prefix for OIDC role names. Must be unique per env in the same AWS account (e.g. 'iac-prod', 'iac-stage')."
  type        = string
  default     = "iac-prod"
}

variable "oidc_environment" {
  description = "GitHub Environment name to constrain the OIDC trust policy to. Defaults to environment_name."
  type        = string
  default     = ""
}

variable "primary_domain" {
  description = "Primary domain for SES identity (covers all subdomains)"
  type        = string
  default     = "example.com"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])+$", var.primary_domain))
    error_message = "primary_domain must be a valid lowercase FQDN."
  }
}

variable "owner" {
  description = "Owner tag value"
  type        = string
  default     = "platform-team"
}

variable "alert_email" {
  description = "Email for SNS security/error alerts"
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address or empty string."
  }
}

variable "monthly_budget_limit_usd" {
  description = "Monthly cost budget limit in USD"
  type        = number
  default     = 5
}

variable "enable_cost_budget" {
  description = "Create AWS Budget with SNS notifications"
  type        = bool
  default     = true
}

variable "enable_ops_dashboard" {
  description = "Create CloudWatch operations dashboard"
  type        = bool
  default     = true
}

variable "enable_console_login" {
  description = "Create console login profiles for team members (passwords stored in state)"
  type        = bool
  default     = false
}

variable "turnstile_secret" {
  description = "Cloudflare Turnstile secret key (leave empty to skip captcha)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "sites" {
  description = "Map of sites to deploy. Key is a short identifier, value defines the site."
  type = map(object({
    domain              = string
    enable_www_redirect = optional(bool, true)
    enable_contact_form = optional(bool, true)
    price_class         = optional(string, "PriceClass_100")
    recipient_email     = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, s in var.sites :
      !try(s.enable_contact_form, true)
      || coalesce(try(s.recipient_email, ""), var.alert_email) != ""
    ])
    error_message = "every site with enable_contact_form=true needs a recipient_email (or set var.alert_email as fallback)."
  }
}

variable "team_members" {
  description = "Team members to create in IAM"
  type = list(object({
    name  = string
    role  = string
    email = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for m in var.team_members : contains(["admin", "developer", "tester"], m.role)
    ])
    error_message = "role must be one of: admin, developer, tester."
  }
}

variable "github_org" {
  description = "GitHub org/user for OIDC trust. Replace YOUR_ORG placeholder before applying."
  type        = string
  default     = "YOUR_ORG"
}

variable "github_repo" {
  description = "GitHub repo name for OIDC trust. Replace YOUR_REPO placeholder before applying."
  type        = string
  default     = "iac-tfm"
}
