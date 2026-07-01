output "infra_sa_email" {
  description = "Terraform infra service account email"
  value       = var.enable_wif ? google_service_account.terraform_infra[0].email : ""
}

output "content_sa_email" {
  description = "Terraform content service account email"
  value       = var.enable_wif ? google_service_account.terraform_content[0].email : ""
}

output "infra_sa_id" {
  description = "Terraform infra service account unique ID"
  value       = var.enable_wif ? google_service_account.terraform_infra[0].unique_id : ""
}

output "content_sa_id" {
  description = "Terraform content service account unique ID"
  value       = var.enable_wif ? google_service_account.terraform_content[0].unique_id : ""
}

output "wif_pool_id" {
  description = "Workload Identity Pool ID"
  value       = var.enable_wif ? google_iam_workload_identity_pool.github[0].workload_identity_pool_id : ""
}

output "wif_pool_name" {
  description = "Workload Identity Pool resource name (full)"
  value       = var.enable_wif ? google_iam_workload_identity_pool.github[0].name : ""
}

output "wif_provider_id" {
  description = "Workload Identity Pool Provider ID"
  value       = var.enable_wif ? google_iam_workload_identity_pool_provider.github[0].workload_identity_pool_provider_id : ""
}

output "wif_provider_name" {
  description = "Workload Identity Pool Provider resource name (full path for GitHub Actions)"
  value       = var.enable_wif ? google_iam_workload_identity_pool_provider.github[0].name : ""
}

output "group_bindings" {
  description = "Map of group emails to IAM roles"
  value = {
    admins     = "group:${local.group_admins} → roles/owner"
    developers = "group:${local.group_developers} → roles/storage.objectAdmin, roles/run.invoker, roles/monitoring.viewer"
    readonly   = "group:${local.group_readonly} → roles/viewer"
  }
}