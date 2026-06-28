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
  type    = string
  default = "dev.harryho.net"
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
  type    = string
  default = "ap-southeast-2"
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
  type    = string
  default = "deploy/azure"
}

variable "sites" {
  type = map(object({
    domain              = string
    enable_contact_form = optional(bool, true)
    recipient_email     = optional(string)
  }))
  default = {}
}