output "sites" {
  value = {
    for k, m in module.static_hosting : k => {
      domain           = m.default_hostname
      custom_domain    = var.sites[k].domain
      static_site_name = m.static_site_name
      validation_token = m.validation_token
    }
  }
  sensitive = true
}

output "github_infra_client_id" {
  value = length(module.workload_identity) > 0 ? module.workload_identity[0].infra_client_id : ""
}

output "github_content_client_id" {
  value = length(module.workload_identity) > 0 ? module.workload_identity[0].content_client_id : ""
}

output "tenant_id" {
  value = length(module.workload_identity) > 0 ? module.workload_identity[0].tenant_id : ""
}

output "subscription_id" {
  value = length(module.workload_identity) > 0 ? module.workload_identity[0].subscription_id : ""
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}