# --------------------------------------------------------------------------
# Contact form Cloud Functions — one per site
# Secret Manager secrets and function source bucket are in infra.tf
# --------------------------------------------------------------------------
module "contact_form" {
  source   = "../../modules/contact-form-fn"
  for_each = var.enable_contact_form ? var.sites : {}

  site_key            = each.key
  site_domain         = each.value.domain
  project_id          = var.project_id
  region              = var.region
  source_bucket       = google_storage_bucket.function_sources.name
  recipient_email     = var.alert_email
  sender_email        = "noreply@${var.site_domain}"
  sendgrid_secret_id  = google_secret_manager_secret.sendgrid_api_key.secret_id
  turnstile_secret_id = google_secret_manager_secret.turnstile_secret.secret_id
  common_labels       = local.common_labels

  depends_on = [
    google_firestore_database.main,
    google_secret_manager_secret_version.sendgrid_api_key,
    google_secret_manager_secret_version.turnstile_secret,
  ]
}