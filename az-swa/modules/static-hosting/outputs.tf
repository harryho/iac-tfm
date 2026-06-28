output "static_site_id" {
  value = azurerm_static_web_app.this.id
}

output "static_site_name" {
  value = azurerm_static_web_app.this.name
}

output "default_hostname" {
  value = azurerm_static_web_app.this.default_host_name
}

output "validation_token" {
  value     = azurerm_static_web_app_custom_domain.this.validation_token
  sensitive = true
}

output "api_key" {
  value     = azurerm_static_web_app.this.api_key
  sensitive = true
}