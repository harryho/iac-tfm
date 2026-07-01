output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "lb_ip_address" {
  description = "Global LB IPv4 address (add this to your DNS provider as an A record for the apex)"
  value       = google_compute_global_address.lb.address
}

output "cert_domains" {
  description = "Domains covered by the managed SSL certificate"
  value       = local.cert_domains
}

output "cert_id" {
  description = "Managed SSL cert resource ID"
  value       = google_compute_managed_ssl_certificate.lb.id
}

output "sites" {
  description = "Deployed sites and their bucket names"
  value = {
    for k, site in module.static_site : k => {
      domain         = site.domain
      bucket_name    = site.bucket_name
      backend_bucket = site.backend_bucket_name
    }
  }
}

output "dns_instructions" {
  description = "DNS records to add at your DNS provider"
  value       = <<-EOT
    LB IP: ${google_compute_global_address.lb.address}

    Add at your DNS provider (zone: ${var.site_domain}):
    1. A Record    @              → ${google_compute_global_address.lb.address}
    2. CNAME       www            → @
    3. CNAME       blogs          → @

    For each additional site, add: CNAME <sub> → @
  EOT
}

output "infra_sa_email" {
  description = "Terraform infra service account email"
  value       = module.team_iam.infra_sa_email
}

output "content_sa_email" {
  description = "Terraform content service account email"
  value       = module.team_iam.content_sa_email
}

output "wif_pool_name" {
  description = "WIF pool name for GitHub Actions"
  value       = module.team_iam.wif_pool_name
}

output "wif_provider_name" {
  description = "WIF provider name for GitHub Actions"
  value       = module.team_iam.wif_provider_name
}

output "function_source_bucket" {
  description = "GCS bucket for Cloud Function source uploads"
  value       = google_storage_bucket.function_sources.name
}

output "sendgrid_secret_id" {
  description = "Secret Manager secret ID for the SendGrid API key (set value via gcloud)"
  value       = google_secret_manager_secret.sendgrid_api_key.secret_id
}

output "turnstile_secret_id" {
  description = "Secret Manager secret ID for the Turnstile secret (set value via gcloud)"
  value       = google_secret_manager_secret.turnstile_secret.secret_id
}

output "ops_dashboard_id" {
  description = "Cloud Monitoring dashboard ID"
  value       = module.ops.dashboard_id
}

output "ops_budget_id" {
  description = "Billing budget ID (empty if budget disabled)"
  value       = module.ops.budget_id
  sensitive   = true
}