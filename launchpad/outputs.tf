output "resource_group_name" {
  value = azurerm_resource_group.launchpad.name
}

output "storage_account_name" {
  value = azurerm_storage_account.launchpad.name
}

output "container_name" {
  value = azurerm_storage_container.tfcafes.name
}