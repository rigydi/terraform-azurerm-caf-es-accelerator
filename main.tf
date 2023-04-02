data "azurerm_client_config" "management" {
  provider = azurerm.management
}

data "azurerm_client_config" "connectivity" {
  provider = azurerm.connectivity
}

data "azurerm_client_config" "core" {}

module "enterprise_scale" {
  source  = "Azure/caf-enterprise-scale/azurerm"
  version = "3.3.0"

  providers = {
    azurerm              = azurerm
    azurerm.connectivity = azurerm.connectivity
    azurerm.management   = azurerm.management
  }

  root_parent_id                = data.azurerm_client_config.core.tenant_id
  root_id                       = var.root_id
  default_location              = var.default_location
  subscription_id_connectivity  = data.azurerm_client_config.connectivity.subscription_id
  subscription_id_management    = data.azurerm_client_config.management.subscription_id
  deploy_connectivity_resources = var.deploy_connectivity_resources
  deploy_management_resources   = var.deploy_management_resources
}
