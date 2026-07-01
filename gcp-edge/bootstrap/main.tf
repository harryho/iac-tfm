terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "current" {}

locals {
  apis = [
    "compute.googleapis.com",
    "storage.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "firestore.googleapis.com",
    "monitoring.googleapis.com",
    "billingbudgets.googleapis.com",
    "iam.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "secretmanager.googleapis.com",
  ]

  common_labels = {
    project    = var.project_name
    managed-by = "terraform"
    component  = "bootstrap"
  }
}

# --------------------------------------------------------------------------
# Enable required APIs
# --------------------------------------------------------------------------
resource "google_project_service" "api" {
  for_each           = toset(local.apis)
  service            = each.value
  project            = var.project_id
  disable_on_destroy = false
}

# --------------------------------------------------------------------------
# GCS bucket for Terraform state
# --------------------------------------------------------------------------
resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_name}-tfstate-${var.project_id}"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age                = 90
      num_newer_versions = 1
    }
    action {
      type = "Delete"
    }
  }

  labels = local.common_labels

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.api]
}

# --------------------------------------------------------------------------
# Grant bootstrap admin objectAdmin on the tfstate bucket
# (the envs' team-iam module will grant the terraform SA later)
# --------------------------------------------------------------------------
resource "google_storage_bucket_iam_binding" "tfstate_admin" {
  bucket  = google_storage_bucket.tfstate.name
  role    = "roles/storage.objectAdmin"
  members = ["user:${var.admin_email}"]

  depends_on = [google_storage_bucket.tfstate]
}