variable "site_key" {
  description = "Short identifier for the site (Terraform map key)"
  type        = string
}

variable "domain" {
  description = "FQDN the site responds to (e.g. www.example.com)"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for GCS bucket and backend bucket names (e.g. gcp-edge-prod)"
  type        = string
}

variable "region" {
  description = "GCP region for the GCS bucket"
  type        = string
  default     = "us-central1"
}

variable "common_labels" {
  description = "Labels applied to all resources"
  type        = map(string)
  default     = {}
}

variable "deployer_sa_email" {
  description = "Service account email for content deployment (gcloud storage rsync). Gets storage.legacyBucketReader on the bucket."
  type        = string
  default     = ""
}