terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }

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