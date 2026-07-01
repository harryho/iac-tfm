variable "project_id" {
  description = "GCP project ID (immutable)"
  type        = string
}

variable "region" {
  description = "GCP region for bootstrap resources"
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "Project name used in resource naming and labels"
  type        = string
  default     = "gcp-edge"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must be lowercase alphanumeric with hyphens only."
  }
}

variable "admin_email" {
  description = "Admin email to grant tfstate bucket access (the human who bootstraps)"
  type        = string
}