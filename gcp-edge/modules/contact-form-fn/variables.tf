variable "site_key" {
  description = "Short identifier for the site (must match the static_site module key)"
  type        = string
}

variable "site_domain" {
  description = "FQDN of the site this form serves (e.g. www.example.com). Used for CORS origin check."
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Function and serverless NEG"
  type        = string
  default     = "us-central1"
}

variable "source_bucket" {
  description = "GCS bucket name for uploading function source zip (shared across functions)"
  type        = string
}

variable "recipient_email" {
  description = "Email address to receive form submissions"
  type        = string
}

variable "sender_email" {
  description = "From address for outbound email (must be on the authenticated SendGrid domain)"
  type        = string
}

variable "sendgrid_secret_id" {
  description = "Secret Manager secret ID containing the SendGrid API key (leave empty to skip email)"
  type        = string
  default     = ""
}

variable "turnstile_secret_id" {
  description = "Secret Manager secret ID containing the Cloudflare Turnstile secret key (leave empty to skip captcha)"
  type        = string
  default     = ""
}

variable "firestore_collection" {
  description = "Firestore collection name for submission records"
  type        = string
  default     = "contact_submissions"
}

variable "max_instance_count" {
  description = "Maximum concurrent instances for the Cloud Function"
  type        = number
  default     = 3
}

variable "common_labels" {
  description = "Labels applied to all resources"
  type        = map(string)
  default     = {}
}