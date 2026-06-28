module "workload_identity" {
  source = "../../modules/workload-identity"
  count  = var.github_org != "" && var.github_repo != "" ? 1 : 0

  project_name        = var.project_name
  environment         = var.environment
  resource_group_name = azurerm_resource_group.main.name
  azure_location      = var.azure_location
  github_org          = var.github_org
  github_repo         = var.github_repo
  github_branch       = var.github_branch
}

data "azurerm_storage_account" "tfstate" {
  count               = var.github_org != "" && var.github_repo != "" ? 1 : 0
  name                = "azswatfstate"
  resource_group_name = "az-swa-tfstate-rg"
}

resource "azurerm_role_assignment" "infra_tfstate" {
  count = var.github_org != "" && var.github_repo != "" ? 1 : 0

  scope                = data.azurerm_storage_account.tfstate[0].id
  role_definition_name = "Storage Account Contributor"
  principal_id         = module.workload_identity[0].infra_principal_id
}