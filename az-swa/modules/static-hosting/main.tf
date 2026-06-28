terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }
}

resource "azurerm_static_web_app" "this" {
  name                = "${replace(var.domain, ".", "-")}-swa"
  resource_group_name = var.resource_group_name
  location            = var.azure_location
  sku_tier            = "Free"
  sku_size            = "Free"
  app_settings        = var.app_settings
}

resource "azurerm_static_web_app_custom_domain" "this" {
  static_web_app_id = azurerm_static_web_app.this.id
  domain_name       = var.domain
  validation_type   = "cname-delegation"

  lifecycle {
    ignore_changes = [validation_type]
  }
}