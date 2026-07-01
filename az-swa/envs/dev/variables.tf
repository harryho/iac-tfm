variable "project_name" {
  type    = string
  default = "az-swa"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "azure_location" {
  type    = string
  default = "eastasia"
}

variable "owner" {
  type    = string
  default = "platform-team"
}

variable "primary_domain" {
  description = "Apex site domain for this env (sites are subdomains of this)"
  type        = string
  default     = "dev.example.com"
}

variable "alert_email" {
  type    = string
  default = ""
}

variable "monthly_budget" {
  type    = number
  default = 5
}

variable "acs_connection_string" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ses_access_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ses_secret_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ses_region" {
  type        = string
  default     = ""
  description = "AWS region for SES fallback (only used if acs_connection_string is empty)"
}

variable "turnstile_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "github_org" {
  type    = string
  default = ""
}

variable "github_repo" {
  type    = string
  default = ""
}

variable "github_branch" {
  type        = string
  default     = "deploy/azure"
  description = "Branch push triggers iac-apply and deploy-content workflows"
}

variable "bootstrap_storage_account_name" {
  type        = string
  default     = "azswatfstate"
  description = "Storage account where bootstrap state lives. Must match the bootstrap module's project_name (default: az-swa → azswatfstate)"
}

variable "bootstrap_resource_group_name" {
  type        = string
  default     = "az-swa-tfstate-rg"
  description = "Resource group where bootstrap state lives. Must match the bootstrap module's project_name (default: az-swa → az-swa-tfstate-rg)"
}

variable "sites" {
  type = map(object({
    domain              = string
    enable_contact_form = optional(bool, true)
    recipient_email     = optional(string)
  }))
  default = {}
}