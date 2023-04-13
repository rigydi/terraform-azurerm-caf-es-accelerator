# Azure Backend Configuration for Terraform State File Management

terraform {
  backend "azurerm" {
    tenant_id            = "83fbc238-dafb-4fd5-8d3f-4ed665854750"
    subscription_id      = "4cf21e62-eb45-47bc-ba0b-6bc5f54d08a8"
    resource_group_name  = "rg-terraform-launchpad-ojn"
    storage_account_name = "stterraformlaunchpadxgw"
    container_name       = "blob-terraform-caf-es-rbd"
    key                  = "terraform-caf-es.tfstate"
  }
}

# Provider Versions and Restrictions

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.51.0"
    }
  }
}

# Azure Provider - Default

provider "azurerm" {
  features {}
}

# Azure Provider - Connectivity

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = "bf59a090-7dd1-4b1c-ab12-853f53d793e1"
  features {}
}

# Azure Provider - Management

provider "azurerm" {
  alias           = "management"
  subscription_id = "d23d0608-39bb-4774-b1f7-9b1bf4956b10"
  features {}
}
