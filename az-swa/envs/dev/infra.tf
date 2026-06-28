resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.azure_location
}

resource "azurerm_communication_service" "this" {
  name                = "${replace(var.project_name, "-", "")}-${var.environment}-acs"
  resource_group_name = azurerm_resource_group.main.name
  data_location       = "United States"
}

resource "azurerm_consumption_budget_resource_group" "monthly" {
  name              = "${var.project_name}-${var.environment}-monthly-budget"
  resource_group_id = azurerm_resource_group.main.id
  amount            = var.monthly_budget
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
  }

  dynamic "notification" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      enabled        = true
      threshold      = 80
      operator       = "GreaterThan"
      contact_emails = [var.alert_email]
    }
  }

  dynamic "notification" {
    for_each = var.alert_email != "" ? [1] : []
    content {
      enabled        = true
      threshold      = 100
      operator       = "GreaterThan"
      contact_emails = [var.alert_email]
    }
  }
}