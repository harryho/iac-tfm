output "bucket_name" {
  description = "GCS bucket name for this site"
  value       = google_storage_bucket.site.name
}

output "backend_bucket_self_link" {
  description = "Self link of the backend bucket (used by the URL map)"
  value       = google_compute_backend_bucket.site.self_link
}

output "backend_bucket_name" {
  description = "Name of the backend bucket"
  value       = google_compute_backend_bucket.site.name
}

output "domain" {
  description = "Domain for this site (passthrough for URL map host rules)"
  value       = var.domain
}

output "site_key" {
  description = "Site key (passthrough for URL map path matcher naming)"
  value       = var.site_key
}