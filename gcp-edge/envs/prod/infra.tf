# --------------------------------------------------------------------------
# Locals for the LB layer
# --------------------------------------------------------------------------
locals {
  # All site domains for the SSL cert
  site_domains = [for site in module.static_site : site.domain]

  # Domains including apex for redirect (only if apex redirect is enabled)
  cert_domains = var.enable_apex_redirect ? concat(local.site_domains, [var.site_domain]) : local.site_domains

  # First site key for the default backend
  first_site_key = keys(var.sites)[0]
}

# --------------------------------------------------------------------------
# Global Anycast IP
# --------------------------------------------------------------------------
resource "google_compute_global_address" "lb" {
  name        = "${var.project_name}-${var.environment}-lb-ip"
  description = "Global LB IP for ${var.project_name} ${var.environment}"
  ip_version  = "IPV4"
}

# --------------------------------------------------------------------------
# Google-managed SSL certificate (covers all site domains + apex)
# --------------------------------------------------------------------------
resource "google_compute_managed_ssl_certificate" "lb" {
  name = "${var.project_name}-${var.environment}-cert"

  managed {
    domains = local.cert_domains
  }
}

# --------------------------------------------------------------------------
# Main URL map — routes hosts to backend buckets, apex → www redirect
# --------------------------------------------------------------------------
resource "google_compute_url_map" "main" {
  name = "${var.project_name}-${var.environment}-url-map"

  # Default backend = first site (catches unmatched hosts)
  default_service = module.static_site[local.first_site_key].backend_bucket_self_link

  # One host rule + path matcher per site
  dynamic "host_rule" {
    for_each = module.static_site
    content {
      hosts        = [host_rule.value.domain]
      path_matcher = "pm-${replace(host_rule.value.site_key, "_", "-")}"
    }
  }

  dynamic "path_matcher" {
    for_each = module.static_site
    content {
      name            = "pm-${replace(path_matcher.value.site_key, "_", "-")}"
      default_service = path_matcher.value.backend_bucket_self_link

      # Route /api/contact* to the contact form Cloud Function (if enabled)
      dynamic "path_rule" {
        for_each = var.enable_contact_form ? [1] : []
        content {
          paths   = ["/api/contact", "/api/contact/*"]
          service = module.contact_form[path_matcher.key].backend_service_self_link
        }
      }
    }
  }

  # Apex redirect: example.com → www.example.com (only if enabled)
  dynamic "host_rule" {
    for_each = var.enable_apex_redirect ? [var.site_domain] : []
    content {
      hosts        = [host_rule.value]
      path_matcher = "pm-apex-redirect"
    }
  }

  dynamic "path_matcher" {
    for_each = var.enable_apex_redirect ? [1] : []
    content {
      name = "pm-apex-redirect"
      default_url_redirect {
        host_redirect  = "www.${var.site_domain}"
        https_redirect = true
        strip_query    = false
      }
    }
  }
}

# --------------------------------------------------------------------------
# HTTPS target proxy + forwarding rule
# --------------------------------------------------------------------------
resource "google_compute_target_https_proxy" "https" {
  name             = "${var.project_name}-${var.environment}-https-proxy"
  url_map          = google_compute_url_map.main.id
  ssl_certificates = [google_compute_managed_ssl_certificate.lb.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name       = "${var.project_name}-${var.environment}-fr-https"
  target     = google_compute_target_https_proxy.https.id
  port_range = "443"
  ip_address = google_compute_global_address.lb.id
}

# --------------------------------------------------------------------------
# HTTP → HTTPS redirect (separate URL map + HTTP proxy + forwarding rule)
# --------------------------------------------------------------------------
resource "google_compute_url_map" "http_redirect" {
  name = "${var.project_name}-${var.environment}-http-redirect"

  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_target_http_proxy" "http" {
  name    = "${var.project_name}-${var.environment}-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name       = "${var.project_name}-${var.environment}-fr-http"
  target     = google_compute_target_http_proxy.http.id
  port_range = "80"
  ip_address = google_compute_global_address.lb.id
}

# --------------------------------------------------------------------------
# Firestore (Native mode) — for contact form submissions
# --------------------------------------------------------------------------
resource "google_firestore_database" "main" {
  name                              = "(default)"
  type                              = "FIRESTORE_NATIVE"
  location_id                       = var.region
  delete_protection_state           = "DELETE_PROTECTION_DISABLED"
  point_in_time_recovery_enablement = "POINT_IN_TIME_RECOVERY_DISABLED"
}

# --------------------------------------------------------------------------
# GCS bucket for Cloud Function source uploads (shared across contact forms)
# --------------------------------------------------------------------------
resource "google_storage_bucket" "function_sources" {
  name                        = "${var.project_name}-${var.environment}-function-sources"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  public_access_prevention    = "inherited"
  labels                      = local.common_labels
}

# --------------------------------------------------------------------------
# Secret Manager — SendGrid API key and Turnstile secret
# Values must be set manually after first apply:
#   echo -n 'SG.xxx' | gcloud secrets versions add sendgrid-api-key --data-file=-
#   echo -n '0xyyy' | gcloud secrets versions add turnstile-secret --data-file=-
# --------------------------------------------------------------------------
resource "google_secret_manager_secret" "sendgrid_api_key" {
  secret_id  = "sendgrid-api-key"
  depends_on = [google_firestore_database.main]

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "sendgrid_api_key" {
  secret      = google_secret_manager_secret.sendgrid_api_key.id
  secret_data = "PLACEHOLDER_SET_VIA_GCLOUD"
}

resource "google_secret_manager_secret" "turnstile_secret" {
  secret_id = "turnstile-secret"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "turnstile_secret" {
  secret      = google_secret_manager_secret.turnstile_secret.id
  secret_data = "PLACEHOLDER_SET_VIA_GCLOUD"
}

# --------------------------------------------------------------------------
# Ops module — budget alerts + monitoring dashboard
# --------------------------------------------------------------------------
module "ops" {
  source = "../../modules/ops"

  project_id               = var.project_id
  region                   = var.region
  alert_email              = var.alert_email
  billing_account_id       = var.billing_account_id
  monthly_budget_limit_usd = var.monthly_budget_limit_usd
  project_name             = var.project_name
  environment              = var.environment
  common_labels            = local.common_labels
}