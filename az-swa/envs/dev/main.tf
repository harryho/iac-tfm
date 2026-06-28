terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }

  # Backend block values are hardcoded (Terraform doesn't allow
  # variables in backend blocks). If you change `project_name` in
  # bootstrap, change these to match:
  #   - storage_account_name: replace(project_name, "-", "") + "tfstate"
  #   - resource_group_name:  project_name + "-tfstate-rg"
  #   - key:                  "az-swa/envs/<env>/terraform.tfstate"
  backend "azurerm" {
    storage_account_name = "azswatfstate"
    container_name       = "tfstate"
    key                  = "az-swa/envs/dev/terraform.tfstate"
    resource_group_name  = "az-swa-tfstate-rg"
  }
}

provider "azurerm" {
  features {}
}