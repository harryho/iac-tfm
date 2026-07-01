locals {
  fn_name  = "contact-${replace(var.site_key, "_", "-")}"
  neg_name = "${local.fn_name}-neg"
  bes_name = "${local.fn_name}-bes"
  sa_id    = substr("${local.fn_name}-sa", 0, 28)

  labels = merge(var.common_labels, { site = replace(var.site_domain, ".", "-"), component = "contact-form" })
}

# --------------------------------------------------------------------------
# Service account — least privilege: Firestore + secret accessor
# --------------------------------------------------------------------------
resource "google_service_account" "function" {
  project      = var.project_id
  account_id   = local.sa_id
  display_name = "Contact form fn SA (${var.site_domain})"
  description  = "Runtime SA for the ${var.site_domain} contact form Cloud Function."
}

resource "google_project_iam_member" "function_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.function.email}"
}

# --------------------------------------------------------------------------
# Secret accessors (only if the secret IDs are provided)
# --------------------------------------------------------------------------
resource "google_secret_manager_secret_iam_member" "sendgrid" {
  count     = var.sendgrid_secret_id != "" ? 1 : 0
  secret_id = var.sendgrid_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function.email}"
}

resource "google_secret_manager_secret_iam_member" "turnstile" {
  count     = var.turnstile_secret_id != "" ? 1 : 0
  secret_id = var.turnstile_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function.email}"
}

# --------------------------------------------------------------------------
# Public invoker — the form posts from the browser with no auth header.
# CF 2nd gen sits on Cloud Run, so the binding is on the underlying service.
# --------------------------------------------------------------------------
resource "google_cloud_run_service_iam_member" "public_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# --------------------------------------------------------------------------
# Build source zip and upload to GCS
# --------------------------------------------------------------------------
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/builds/${local.fn_name}.zip"
}

resource "google_storage_bucket_object" "source" {
  name   = "sources/${local.fn_name}/${data.archive_file.source.output_md5}.zip"
  bucket = var.source_bucket
  source = data.archive_file.source.output_path
}

# --------------------------------------------------------------------------
# Cloud Function 2nd gen (backed by Cloud Run)
# --------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "this" {
  project     = var.project_id
  name        = local.fn_name
  location    = var.region
  description = "Contact form handler for ${var.site_domain}"

  labels = local.labels

  build_config {
    runtime     = "nodejs20"
    entry_point = "contactForm"
    source {
      storage_source {
        bucket = google_storage_bucket_object.source.bucket
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    max_instance_count    = var.max_instance_count
    min_instance_count    = 0
    available_memory      = "256Mi"
    timeout_seconds       = 60
    available_cpu         = 1
    service_account_email = google_service_account.function.email
    ingress_settings      = "ALLOW_ALL"

    environment_variables = {
      SITE_DOMAIN          = var.site_domain
      RECIPIENT_EMAIL      = var.recipient_email
      SENDER_EMAIL         = var.sender_email
      FIRESTORE_COLLECTION = var.firestore_collection
    }

    dynamic "secret_environment_variables" {
      for_each = var.sendgrid_secret_id != "" ? [1] : []
      content {
        key        = "SENDGRID_API_KEY"
        project_id = var.project_id
        secret     = var.sendgrid_secret_id
        version    = "latest"
      }
    }

    dynamic "secret_environment_variables" {
      for_each = var.turnstile_secret_id != "" ? [1] : []
      content {
        key        = "TURNSTILE_SECRET"
        project_id = var.project_id
        secret     = var.turnstile_secret_id
        version    = "latest"
      }
    }
  }
}

# --------------------------------------------------------------------------
# Serverless NEG + Backend Service — for LB path-rule routing
# --------------------------------------------------------------------------
resource "google_compute_region_network_endpoint_group" "serverless" {
  project               = var.project_id
  name                  = local.neg_name
  region                = var.region
  network_endpoint_type = "SERVERLESS"

  cloud_function {
    function = google_cloudfunctions2_function.this.name
  }
}

resource "google_compute_backend_service" "serverless" {
  project               = var.project_id
  name                  = local.bes_name
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  enable_cdn            = false

  backend {
    group = google_compute_region_network_endpoint_group.serverless.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# --------------------------------------------------------------------------
# Monitoring alert — function error rate
# --------------------------------------------------------------------------
resource "google_monitoring_alert_policy" "errors" {
  project      = var.project_id
  display_name = "Contact form errors — ${var.site_domain}"
  combiner     = "OR"

  conditions {
    display_name = "Error count > 0 (5m)"
    condition_threshold {
      filter          = "resource.type=\"cloud_function\" AND resource.label.function_name=\"${google_cloudfunctions2_function.this.name}\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\" AND metric.label.status=\"error\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }
}