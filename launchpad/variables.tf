variable "subscription_id" {
  description = "The ID of the Azure subscription in which the launchpad resources will be deployed."
  type        = string
}

variable "tenant_id" {
  description = "The Azure Active Directory Tenant ID."
  type        = string
}

variable "basename" {
  description = "The string which will be used for naming all resources."
  type        = string
  default     = "terraform-launchpad"
}

variable "random_length" {
  description = "A random suffix string added to each resource name."
  type        = number
  default     = 3
}

variable "location" {
  description = "Defines the region in which the resources will be deployed, e.g. westeurope."
  type        = string
}

variable "account_tier" {
  description = "Defines the Tier to use for this storage account. Valid options are Standard and Premium. For BlockBlobStorage and FileStorage accounts only Premium is valid. Changing this forces a new resource to be created."
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "Defines the type of replication to use for this storage account. Valid options are LRS, GRS, RAGRS, ZRS, GZRS and RAGZRS."
  type        = string
  default     = "LRS"
}
