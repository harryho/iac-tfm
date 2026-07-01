locals {
  bucket_name = "${var.bucket_prefix}-${replace(var.site_key, "_", "-")}"
  bb_name     = "${var.bucket_prefix}-${replace(var.site_key, "_", "-")}-bb"
  site_labels = merge(var.common_labels, { site = replace(var.domain, ".", "-") })
}

# --------------------------------------------------------------------------
# GCS bucket — private origin (served only via backend bucket + Cloud CDN)
# --------------------------------------------------------------------------
resource "google_storage_bucket" "site" {
  name                        = local.bucket_name
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

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

  labels = local.site_labels
}

# --------------------------------------------------------------------------
# Backend bucket — connects GCS to the LB with Cloud CDN enabled
# --------------------------------------------------------------------------
resource "google_compute_backend_bucket" "site" {
  name        = local.bb_name
  description = "CDN backend for ${var.domain}"
  bucket_name = google_storage_bucket.site.name
  enable_cdn  = true

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 3600
    max_ttl           = 86400
    negative_caching  = true
    serve_while_stale = 86400
  }
}

# --------------------------------------------------------------------------
# Error pages — uploaded as objects in the bucket
# --------------------------------------------------------------------------
resource "google_storage_bucket_object" "error_404" {
  name         = "404.html"
  bucket       = google_storage_bucket.site.name
  content      = "<html><body><h1>404 - Not Found</h1><p>The page you requested does not exist.</p></body></html>"
  content_type = "text/html; charset=utf-8"
}

resource "google_storage_bucket_object" "error_500" {
  name         = "500.html"
  bucket       = google_storage_bucket.site.name
  content      = "<html><body><h1>500 - Server Error</h1><p>Something went wrong.</p></body></html>"
  content_type = "text/html; charset=utf-8"
}

# --------------------------------------------------------------------------
# Bucket IAM — content deployer SA needs storage.buckets.get for
# gcloud storage rsync (not included in roles/storage.objectAdmin)
# --------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "deployer" {
  count  = var.deployer_sa_email != "" ? 1 : 0
  bucket = google_storage_bucket.site.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${var.deployer_sa_email}"
}