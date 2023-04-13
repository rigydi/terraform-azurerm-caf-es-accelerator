###############################################################
# Information
###############################################################

# This module deploys Azure resources to enable Terraform state file management on Azure.
# The resource composition is referred to as "launchpad".


###############################################################
# Local Variables
###############################################################

locals {
  tags = {
    environment = "terraform launchpad"
    managedby   = "terraform"
  }
}

##################################
# Management Group for Launchpad
##################################

data "azurerm_management_group" "root" {
  display_name = "Tenant Root Group"
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_group
resource "azurerm_management_group" "launchpad" {
  display_name               = var.management_group_display_name
  parent_management_group_id = data.azurerm_management_group.root.id

  subscription_ids = ["${var.subscription_id}"]
}


##################################
# Resource Group for Launchpad
##################################

# https://registry.terraform.io/providers/aztfmod/azurecaf/latest
resource "azurecaf_name" "rg" {
  name          = var.basename
  resource_type = "azurerm_resource_group"
  random_length = var.random_length
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "launchpad" {
  name       = azurecaf_name.rg.result
  location   = var.location
  tags       = local.tags
  depends_on = [azurerm_management_group.launchpad]
}


##################################
# Storage Account for Terraform State files
##################################

# https://registry.terraform.io/providers/aztfmod/azurecaf/latest
resource "azurecaf_name" "stracc" {
  name          = var.basename
  resource_type = "azurerm_storage_account"
  random_length = var.random_length
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
resource "azurerm_storage_account" "launchpad" {
  name                     = azurecaf_name.stracc.result
  resource_group_name      = azurerm_resource_group.launchpad.name
  location                 = azurerm_resource_group.launchpad.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  tags                     = local.tags
}


##################################
# Blob Container for Launchpad Terraform state file
##################################

# https://registry.terraform.io/providers/aztfmod/azurecaf/latest
resource "azurecaf_name" "bloblaunchpad" {
  name          = var.basename
  resource_type = "azurerm_storage_blob"
  random_length = var.random_length
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container
resource "azurerm_storage_container" "launchpad" {
  name                  = azurecaf_name.bloblaunchpad.result
  storage_account_name  = azurerm_storage_account.launchpad.name
  container_access_type = "private"

  lifecycle { prevent_destroy = true }
}


##################################
# Blob Container for Terraform CAF Enterprise Scale (tfcafes) state file
##################################

# https://registry.terraform.io/providers/aztfmod/azurecaf/latest
resource "azurecaf_name" "tfcafes" {
  name          = "terraform-caf-es"
  resource_type = "azurerm_storage_blob"
  random_length = var.random_length
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container
resource "azurerm_storage_container" "tfcafes" {
  name                  = azurecaf_name.tfcafes.result
  storage_account_name  = azurerm_storage_account.launchpad.name
  container_access_type = "private"

  lifecycle { prevent_destroy = true }
}