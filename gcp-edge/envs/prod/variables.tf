variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "Project name used in resource naming and labels"
  type        = string
  default     = "gcp-edge"
}

variable "environment" {
  description = "Environment name (used in labels and resource naming)"
  type        = string
  default     = "prod"
}

variable "site_domain" {
  description = "Apex site domain (the domain the websites are hosted on). The apex is redirected to www.<site_domain>."
  type        = string
  default     = "example.com"
}

variable "org_domain" {
  description = "Cloud Identity org domain (e.g. example.org). Used for team-iam group email addresses."
  type        = string
  default     = "example.org"
}

variable "alert_email" {
  description = "Email for budget and monitoring alerts"
  type        = string
}

variable "monthly_budget_limit_usd" {
  description = "Monthly cost budget limit in USD"
  type        = number
  default     = 5
}

variable "sites" {
  description = "Map of sites to deploy. Key is a short identifier, value defines the site."
  type = map(object({
    domain              = string
    enable_www_redirect = optional(bool, true)
  }))
  default = {
    www_example_com = {
      domain = "www.example.com"
    }
    blogs_example_com = {
      domain              = "blogs.example.com"
      enable_www_redirect = false
    }
  }
}

variable "github_org" {
  description = "GitHub org/user for WIF trust (leave empty to skip CI roles)"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repo name for WIF trust (leave empty to skip CI roles)"
  type        = string
  default     = ""
}

variable "github_envs" {
  description = "List of GitHub environments allowed to authenticate via WIF"
  type        = list(string)
  default     = ["production"]
}

variable "turnstile_secret" {
  description = "Cloudflare Turnstile secret key (leave empty to skip captcha)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_contact_form" {
  description = "Create the contact form Cloud Function + LB routing for /api/contact*"
  type        = bool
  default     = true
}

variable "enable_apex_redirect" {
  description = "Redirect the apex domain (site_domain) to www.<site_domain> via the LB"
  type        = bool
  default     = true
}

variable "billing_account_id" {
  description = "Billing account ID (e.g. XXXXXX-YYYYYY-ZZZZZZ). Leave empty to skip budget creation."
  type        = string
  default     = ""
  sensitive   = true
}

variable "state_bucket_name" {
  description = "GCS bucket holding terraform state for this env (set by replicate-env.sh)"
  type        = string
  default     = "gcp-edge-tfstate-your-project-id"
}