terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Backend values match the bootstrap output. If you change project_name
  # or project_id, update `bucket` here to match.
  #
  #   bucket = "${project_name}-tfstate-${project_id}"
  #
  # The `prefix` is per-env: replicate-env.sh rewrites it for new envs.
  backend "gcs" {
    bucket = "gcp-edge-tfstate-your-project-id"
    prefix = "gcp-edge/envs/prod"
  }
}

# --------------------------------------------------------------------------
# Providers
# --------------------------------------------------------------------------
provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = local.common_labels
}

# --------------------------------------------------------------------------
# Data sources
# --------------------------------------------------------------------------
data "google_client_config" "current" {}

# --------------------------------------------------------------------------
# Locals
# --------------------------------------------------------------------------
locals {
  common_labels = {
    project    = var.project_name
    managed-by = "terraform"
    env        = var.environment
  }
}