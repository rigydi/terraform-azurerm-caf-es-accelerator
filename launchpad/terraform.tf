###############################################################
# Provider and Version Restrictions
###############################################################

terraform {
  required_version = "~> 1.3"
  required_providers {
    azurerm = "~> 3.49" # https://registry.terraform.io/providers/hashicorp/azurerm/latest
    azurecaf = {
      source  = "aztfmod/azurecaf" # https://registry.terraform.io/providers/aztfmod/azurecaf/latest/docs
      version = "~> 1.2"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  features {}
}