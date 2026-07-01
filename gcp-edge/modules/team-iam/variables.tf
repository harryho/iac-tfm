variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "project_name" {
  description = "Project name (used as prefix for Cloud Identity group names, e.g. <project_name>-admins@<org_domain>)"
  type        = string
  default     = "gcp-edge"
}

variable "org_domain" {
  description = "Cloud Identity org domain for group email addresses (e.g. example.org)"
  type        = string
}

variable "state_bucket_name" {
  description = "GCS state bucket name for granting infra SA access"
  type        = string
}

variable "github_org" {
  description = "GitHub org/username for OIDC trust (leave empty to skip WIF)"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repo name for OIDC trust (leave empty to skip WIF)"
  type        = string
  default     = ""
}

variable "github_envs" {
  description = "List of GitHub environment names allowed to authenticate via WIF"
  type        = list(string)
  default     = ["production"]
}

variable "enable_wif" {
  description = "Create WIF pool, provider, and service accounts"
  type        = bool
  default     = true
}

variable "common_labels" {
  description = "Common labels to apply to resources"
  type        = map(string)
  default     = {}
}