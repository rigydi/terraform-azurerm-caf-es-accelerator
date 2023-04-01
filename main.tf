data "azurerm_client_config" "core" {}

module "enterprise_scale" {
  source  = "Azure/caf-enterprise-scale/azurerm"
  version = "3.3.0"

  providers = {
    azurerm              = azurerm
    azurerm.connectivity = azurerm
    azurerm.management   = azurerm
  }

  root_parent_id                = data.azurerm_client_config.core.tenant_id
  root_id                       = var.root_id
  default_location              = var.default_location
  deploy_connectivity_resources = var.deploy_connectivity_resources
  deploy_management_resources   = var.deploy_management_resources
}
