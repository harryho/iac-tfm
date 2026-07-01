output "state_bucket_name" {
  description = "Name of the GCS bucket storing Terraform state"
  value       = google_storage_bucket.tfstate.name
}

output "state_bucket_url" {
  description = "gs:// URL of the tfstate bucket"
  value       = "gs://${google_storage_bucket.tfstate.name}"
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "instructions" {
  description = "Next steps after bootstrap"
  value       = <<-EOT
    Bootstrap complete. The GCS backend bucket is ready.

    State bucket: ${google_storage_bucket.tfstate.name}
    Region:       ${var.region}
    Project:      ${var.project_id}

    Next step: cd ../envs/prod && terraform init

    The backend block in envs/prod/main.tf already points at this bucket.
    Run terraform init there to confirm state storage works.
  EOT
}