output "function_name" {
  description = "Cloud Function 2nd gen name"
  value       = google_cloudfunctions2_function.this.name
}

output "function_uri" {
  description = "Cloud Function HTTPS URI (direct invocation, bypasses LB)"
  value       = google_cloudfunctions2_function.this.url
}

output "service_account_email" {
  description = "Service account the function runs as"
  value       = google_service_account.function.email
}

output "backend_service_self_link" {
  description = "Self link of the backend service (for LB URL map path rules)"
  value       = google_compute_backend_service.serverless.self_link
}

output "neg_self_link" {
  description = "Self link of the serverless NEG"
  value       = google_compute_region_network_endpoint_group.serverless.id
}

output "log_name" {
  description = "Cloud Logging log name pattern for this function"
  value       = "projects/${var.project_id}/logs/cloudfunctions.googleapis.com%2Fcloud-functions"
}