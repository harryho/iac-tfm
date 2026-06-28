terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "infra" {
  name                = "${var.project_name}-${var.environment}-infra-id"
  resource_group_name = var.resource_group_name
  location            = var.azure_location
}

resource "azurerm_user_assigned_identity" "content" {
  name                = "${var.project_name}-${var.environment}-content-id"
  resource_group_name = var.resource_group_name
  location            = var.azure_location
}

# Federated credentials: branch push, pull_request, and environment (for OIDC only).
resource "azurerm_federated_identity_credential" "infra" {
  name                = "${var.project_name}-${var.environment}-infra-fic"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.infra.id
  subject             = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
}

resource "azurerm_federated_identity_credential" "infra_pr" {
  name                = "${var.project_name}-${var.environment}-infra-fic-pr"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.infra.id
  subject             = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

resource "azurerm_federated_identity_credential" "infra_env" {
  name                = "${var.project_name}-${var.environment}-infra-fic-env"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.infra.id
  subject             = "repo:${var.github_org}/${var.github_repo}:environment:${var.environment}"
}

resource "azurerm_federated_identity_credential" "content" {
  name                = "${var.project_name}-${var.environment}-content-fic"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.content.id
  subject             = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
}

resource "azurerm_federated_identity_credential" "content_pr" {
  name                = "${var.project_name}-${var.environment}-content-fic-pr"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.content.id
  subject             = "repo:${var.github_org}/${var.github_repo}:pull_request"
}

resource "azurerm_federated_identity_credential" "content_env" {
  name                = "${var.project_name}-${var.environment}-content-fic-env"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  parent_id           = azurerm_user_assigned_identity.content.id
  subject             = "repo:${var.github_org}/${var.github_repo}:environment:${var.environment}"
}

resource "azurerm_role_assignment" "infra" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.infra.principal_id
}

# ponytail: Contributor is the narrowest built-in role that grants
# `Microsoft.Web/staticSites/*` (needed for `az staticwebapp secrets list`).
# If least-privilege matters, replace with a custom role scoped to
# staticSites on this RG.
resource "azurerm_role_assignment" "content" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.content.principal_id
}