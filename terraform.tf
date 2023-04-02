terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.50.0"
    }
  }
}

terraform {
  backend "azurerm" {
    tenant_id            = "tenant_idasdfasdf"
    subscription_id      = "subsc_idasdfasdf"
    resource_group_name  = "rg-asdfasdf"
    storage_account_name = "strasdfasdf"
    container_name       = "containerasdfasdf"
    key                  = "terraform-caf-es.tfstate"
  }
}

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = "connectsubscr"
  features {}
}

provider "azurerm" {
  alias           = "management"
  subscription_id = "managesubsc"
  features {}
}
