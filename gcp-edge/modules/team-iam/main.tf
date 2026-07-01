data "google_project" "current" {
  project_id = var.project_id
}

locals {
  group_admins     = "${var.project_name}-admins@${var.org_domain}"
  group_developers = "${var.project_name}-developers@${var.org_domain}"
  group_readonly   = "${var.project_name}-readonly@${var.org_domain}"
}

# --------------------------------------------------------------------------
# IAM bindings for Cloud Identity groups
# Groups must already exist in Cloud Identity (created via gcloud or Admin UI).
# --------------------------------------------------------------------------
resource "google_project_iam_member" "admins" {
  project = var.project_id
  role    = "roles/owner"
  member  = "group:${local.group_admins}"
}

resource "google_project_iam_member" "developers_storage" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "group:${local.group_developers}"
}

resource "google_project_iam_member" "developers_run" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "group:${local.group_developers}"
}

resource "google_project_iam_member" "developers_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "group:${local.group_developers}"
}

resource "google_project_iam_member" "readonly" {
  project = var.project_id
  role    = "roles/viewer"
  member  = "group:${local.group_readonly}"
}

# --------------------------------------------------------------------------
# Workload Identity Federation — GitHub Actions OIDC
# --------------------------------------------------------------------------
resource "google_iam_workload_identity_pool" "github" {
  count = var.enable_wif ? 1 : 0

  workload_identity_pool_id = "${var.project_name}-github-wif"
  display_name              = "${var.project_name}-github-wif"
  description               = "Workload Identity Pool for GitHub Actions (${var.github_org}/${var.github_repo})"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  count = var.enable_wif ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.github[0].workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub Actions OIDC"
  description                        = "OIDC provider for GitHub Actions (${var.github_org}/${var.github_repo})"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.environment" = "assertion.environment"
    "attribute.ref"         = "assertion.ref"
    "attribute.actor"       = "assertion.actor"
  }

  attribute_condition = "attribute.repository == \"${var.github_org}/${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --------------------------------------------------------------------------
# Service accounts for GitHub Actions
# --------------------------------------------------------------------------
resource "google_service_account" "terraform_infra" {
  count = var.enable_wif ? 1 : 0

  account_id   = "terraform-infra"
  display_name = "Terraform Infra"
  description  = "Used by GitHub Actions for terraform plan/apply. Managed by ${var.project_name}."
}

resource "google_service_account" "terraform_content" {
  count = var.enable_wif ? 1 : 0

  account_id   = "terraform-content"
  display_name = "Terraform Content"
  description  = "Used by GitHub Actions for content deploy (gcloud storage rsync + cache invalidation). Managed by ${var.project_name}."
}

# --------------------------------------------------------------------------
# SA IAM bindings — infra SA gets owner + state bucket access
# --------------------------------------------------------------------------
resource "google_project_iam_member" "infra_sa_owner" {
  count   = var.enable_wif ? 1 : 0
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.terraform_infra[0].email}"
}

resource "google_storage_bucket_iam_member" "infra_sa_state" {
  count  = var.enable_wif ? 1 : 0
  bucket = var.state_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_infra[0].email}"
}

# --------------------------------------------------------------------------
# SA IAM bindings — content SA gets objectAdmin on content buckets
# (applied at project level, scoped via bucket naming convention)
# --------------------------------------------------------------------------
resource "google_project_iam_member" "content_sa_storage" {
  count   = var.enable_wif ? 1 : 0
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.terraform_content[0].email}"
}

# --------------------------------------------------------------------------
# WIF → SA impersonation bindings
# Allow the WIF pool to impersonate the service accounts
# --------------------------------------------------------------------------
resource "google_service_account_iam_member" "wif_infra" {
  count = var.enable_wif ? 1 : 0

  service_account_id = google_service_account.terraform_infra[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github[0].workload_identity_pool_id}/attribute.repository/${var.github_org}/${var.github_repo}"
}

resource "google_service_account_iam_member" "wif_content" {
  count = var.enable_wif ? 1 : 0

  service_account_id = google_service_account.terraform_content[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github[0].workload_identity_pool_id}/attribute.repository/${var.github_org}/${var.github_repo}"
}

# --------------------------------------------------------------------------
# Cloud Functions 2nd gen build SA: default compute SA needs Cloud Build
# See: https://cloud.google.com/functions/docs/troubleshooting#build-service-account
# --------------------------------------------------------------------------
resource "google_project_iam_member" "compute_sa_cloudbuild" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "compute_sa_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.current.number}-compute@developer.gserviceaccount.com"
}

# --------------------------------------------------------------------------
# Content SA — also needs to invalidate the CDN cache after deploy
# (compute.loadBalancerAdmin includes compute.urlMaps.invalidateCache)
# --------------------------------------------------------------------------
resource "google_project_iam_member" "content_sa_urlmaps" {
  count   = var.enable_wif ? 1 : 0
  project = var.project_id
  role    = "roles/compute.loadBalancerAdmin"
  member  = "serviceAccount:${google_service_account.terraform_content[0].email}"
}