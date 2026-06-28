output "infra_client_id" {
  value = azurerm_user_assigned_identity.infra.client_id
}

output "infra_principal_id" {
  value = azurerm_user_assigned_identity.infra.principal_id
}

output "content_client_id" {
  value = azurerm_user_assigned_identity.content.client_id
}

output "content_principal_id" {
  value = azurerm_user_assigned_identity.content.principal_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}