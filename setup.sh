#!/usr/bin/env bash

# exit on error
set -e

###########################################
# Variables
###########################################

FILE_PROVIDERS="terraform.tf"
FILE_MAIN="main.tf"
FILE_VARIABLES="variables.tf"
FILE_TFVARS="terraform.tfvars"
FILE_SETTINGS="settings.yaml"

ROOT_ID=$(yq '.settings.core.root_id' $FILE_SETTINGS)
ROOT_NAME=$(yq '.settings.core.root_name' $FILE_SETTINGS)

CONNECTIVITY_DEPLOY=$(yq '.settings.connectivity.deploy' $FILE_SETTINGS)
CONNECTIVITY_SUBSCRIPTION_ID=$(yq '.settings.connectivity.subscription_id' $FILE_SETTINGS)

MANAGEMENT_DEPLOY=$(yq '.settings.management.deploy' $FILE_SETTINGS)
MANAGEMENT_SUBSCRIPTION_ID=$(yq '.settings.management.subscription_id' $FILE_SETTINGS)

###########################################
# Functions
###########################################

# used for making the console output more readable
function print_empty_lines() {
  for (( i=1; i<=$1; i++ ))
  do
    echo ""
  done
}

# clean up files
clean_up () {
  rm -rvf *.tf .terraform* *.tfvars *.tfstate* >/dev/null 2>&1
}

###########################################
# Some preparation steps
###########################################

# echo -n "Clean up all files? (yes/no): "
# read CLEAN_UP

# if [ "$CLEAN_UP" == "yes" ]; then
#   clean_up
# fi

clean_up

###########################################
# Create FILE_PROVIDERS
###########################################

AZURERM_LATEST_VERSION=$(curl -s -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/hashicorp/terraform-provider-azurerm/releases/latest | jq -r ".tag_name" | sed 's/v//g')

echo "Creating terraform.tf."
cat <<EOF > $FILE_PROVIDERS
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= $AZURERM_LATEST_VERSION"
    }
  }
}
EOF


###########################################
# Create FILE_VARIABLES
###########################################

echo "Creating variables.tf."

cat <<EOF > $FILE_VARIABLES
variable "root_id" {
  description = "If specified, will set a custom Name (ID) value for the Enterprise-scale \"root\" Management Group, and append this to the ID for all core Enterprise-scale Management Groups."
  type        = string
  default     = "$ROOT_ID"
}

variable "root_name" {
  description = "If specified, will set a custom Display Name value for the Enterprise-scale \"root\" Management Group."
  type        = string
  default     = "$ROOT_NAME"
}
EOF


###########################################
# Create basic FILE_MAIN
###########################################

ES_VERSION=$(curl -s -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/Azure/terraform-azurerm-caf-enterprise-scale/releases/latest | jq -r ".tag_name" | sed 's/v//g')

echo "Creating main.tf."

cat <<EOF > $FILE_MAIN
data "azurerm_client_config" "core" {}

module "enterprise_scale" {
  source  = "Azure/caf-enterprise-scale/azurerm"
  version = "$ES_VERSION"

  providers = {
    azurerm = azurerm
    azurerm.connectivity = azurerm
    azurerm.management = azurerm
  }

  root_parent_id = data.azurerm_client_config.core.tenant_id
EOF


###########################################
# <>_SUBSCRIPTION_ID conditions
###########################################

if [ -n "$CONNECTIVITY_SUBSCRIPTION_ID" ]; then
  echo "Configuring connectivity provider."
  sed -i 's/azurerm.connectivity = azurerm/azurerm.connectivity = azurerm.connectivity/' main.tf

  cat <<EOF >> $FILE_PROVIDERS

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = "$CONNECTIVITY_SUBSCRIPTION_ID"
  features {}
}
EOF

  cat <<EOF >> tmp.txt
data "azurerm_client_config" "connectivity" {
  provider = azurerm.connectivity
}

EOF

cat $FILE_MAIN >> tmp.txt
mv tmp.txt $FILE_MAIN
echo "subscription_id_connectivity = data.azurerm_client_config.connectivity.subscription_id" >> $FILE_MAIN
fi

if [ -n "$MANAGEMENT_SUBSCRIPTION_ID" ]; then
  echo "Configuring management provider."
  sed -i 's/azurerm.management = azurerm/azurerm.management = azurerm.management/' main.tf

  cat <<EOF >> $FILE_PROVIDERS

provider "azurerm" {
  alias           = "management"
  subscription_id = "$MANAGEMENT_SUBSCRIPTION_ID"
  features {}
}
EOF

  cat <<EOF >> tmp.txt
data "azurerm_client_config" "management" {
  provider = azurerm.management
}

EOF

cat $FILE_MAIN >> tmp.txt
mv tmp.txt $FILE_MAIN
echo "subscription_id_management = data.azurerm_client_config.management.subscription_id" >> $FILE_MAIN
fi

###########################################
# <>_DEPLOY conditions
###########################################

if [ "$CONNECTIVITY_DEPLOY" == true ]; then
  echo "Adding variable: deploy_connectivity_resources."
  cat <<EOF >> $FILE_VARIABLES

variable "deploy_connectivity_resources" {
  type        = bool
  description = "If set to true, will enable the \"Connectivity\" landing zone settings and add \"Connectivity\" resources into the current Subscription context."
  default     = true
}
EOF
else
  echo "Adding variable: deploy_connectivity_resources."
  cat <<EOF >> $FILE_VARIABLES

variable "deploy_connectivity_resources" {
  type        = bool
  description = "If set to true, will enable the \"Connectivity\" landing zone settings and add \"Connectivity\" resources into the current Subscription context."
  default     = false
}
EOF
fi

echo "deploy_connectivity_resources = var.deploy_connectivity_resources" >> $FILE_MAIN

if [ "$MANAGEMENT_DEPLOY" == true ]; then
  echo "Adding variable: deploy_management_resources."
  cat <<EOF >> $FILE_VARIABLES

variable "deploy_management_resources" {
  type        = bool
  description = "If set to true, will enable the \"Management\" landing zone settings and add \"Management\" resources into the current Subscription context."
  default     = true
}
EOF
else
  echo "Adding variable: deploy_management_resources."
  cat <<EOF >> $FILE_VARIABLES

variable "deploy_management_resources" {
  type        = bool
  description = "If set to true, will enable the \"Management\" landing zone settings and add \"Management\" resources into the current Subscription context."
  default     = false
}
EOF
fi

echo "deploy_management_resources = var.deploy_management_resources" >> $FILE_MAIN


###########################################
# Post steps
###########################################

# Add closing bracket to FILE_MAIN
echo "}" >> $FILE_MAIN

# Format all Terraform files
terraform fmt > /dev/null 2>&1