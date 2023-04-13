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

  # Core
  root_parent_id   = data.azurerm_client_config.core.tenant_id
  root_id          = var.root_id
  default_location = var.default_location

  # Connectivity
  subscription_id_connectivity     = data.azurerm_client_config.connectivity.subscription_id
  deploy_connectivity_resources    = var.deploy_connectivity_resources
  configure_connectivity_resources = local.configure_connectivity_resources

  # Management
  subscription_id_management     = data.azurerm_client_config.management.subscription_id
  deploy_management_resources    = var.deploy_management_resources
  configure_management_resources = local.configure_management_resources

  # Custom Management Groups
  custom_landing_zones = {
    "${var.root_id}-mygroup" = {
      display_name               = "${upper(var.root_id)} MY GROUP"
      parent_management_group_id = "${var.root_id}-landing_zone"
      subscription_ids           = [""]
      archetype_config = {
        archetype_id   = "default_empty"
        parameters     = {}
        access_control = {}
      }
    }
    "${var.root_id}-launchpad" = {
      display_name               = "${upper(var.root_id)} Launchpad"
      parent_management_group_id = "${var.root_id}"
      subscription_ids           = ["4cf21e62-eb45-47bc-ba0b-6bc5f54d08a8"]
      archetype_config = {
        archetype_id   = "default_empty"
        parameters     = {}
        access_control = {}
      }
    }
  }
}
