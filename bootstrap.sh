#!/usr/bin/env bash

###########################################
# Variables
###########################################

FILE_PROVIDERS="terraform.tf"
FILE_MAIN="main.tf"
FILE_VARIABLES="variables.tf"
FILE_TFVARS="terraform.tfvars"
FILE_SETTINGS="bootstrap.yaml"
FILE_BACKEND_LAUNCHPAD="backend.tf"
FILE_LOCALS_CONNECTIVITY="settings.connectivity.tf"
FILE_LOCALS_MANAGEMENT="settings.management.tf"

array_terraform_files=($FILE_PROVIDERS $FILE_MAIN $FILE_VARIABLES $FILE_TFVARS $FILE_SETTINGS $FILE_LOCALS_CONNECTIVITY $FILE_LOCALS_MANAGEMENT)
FOLDER_BACKUP="backup"
FOLDER_LAUNCHPAD="launchpad"

BACKEND_CONFIGURE=$(yq '.settings.backend.configure' $FILE_SETTINGS)
# BACKEND_TENANT_ID=$(yq '.settings.backend.tenant_id' $FILE_SETTINGS)
# BACKEND_SUBSCRIPTION_ID=$(yq '.settings.backend.subscription_id' $FILE_SETTINGS)
# BACKEND_RESOURCE_GROUP_NAME=$(yq '.settings.backend.resource_group_name' $FILE_SETTINGS)
# BACKEND_STORAGE_ACCOUNT_NAME=$(yq '.settings.backend.storage_account_name' $FILE_SETTINGS)
# BACKEND_CONTAINER_NAME=$(yq '.settings.backend.container_name' $FILE_SETTINGS)
# BACKEND_STATE_FILENAME=$(yq '.settings.backend.key' $FILE_SETTINGS)
BACKEND_STATE_FILENAME="terraform-caf-es.tfstate"

ROOT_ID=$(yq '.settings.core.root_id' $FILE_SETTINGS)
ROOT_NAME=$(yq '.settings.core.root_name' $FILE_SETTINGS)
DEFAULT_LOCATION=$(yq '.settings.core.default_location' $FILE_SETTINGS)

CONNECTIVITY_DEPLOY=$(yq '.settings.connectivity.deploy' $FILE_SETTINGS)
CONNECTIVITY_SUBSCRIPTION_ID=$(yq '.settings.connectivity.subscription_id' $FILE_SETTINGS)
CONNECTIVITY_CUSTOM=$(yq '.settings.connectivity.customize' $FILE_SETTINGS)

MANAGEMENT_DEPLOY=$(yq '.settings.management.deploy' $FILE_SETTINGS)
MANAGEMENT_SUBSCRIPTION_ID=$(yq '.settings.management.subscription_id' $FILE_SETTINGS)
MANAGEMENT_CUSTOM=$(yq '.settings.management.customize' $FILE_SETTINGS)

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
cleanup () {
  rm -rvf *.tf .terraform* *.tfvars *.tfstate* >/dev/null 2>&1
}

function backup () {

  if [ ! -d "./$FOLDER_BACKUP" ]
  then
      mkdir -p ./$FOLDER_BACKUP > /dev/null 2>&1
  fi

  for file in "${array_terraform_files[@]}"
  do
    if [[ -z $file ]]
    then
      echo "File $file is not existing. No backup necessary."
    else
      echo "Backing up: $file"
      cp "$file" ./$FOLDER_BACKUP > /dev/null 2>&1
    fi
  done
}

function handle_interrupt () {
  print_empty_lines 2
  echo "Backing up files to folder ./$FOLDER_BACKUP."
  backup
  echo "Cleaning up files."
  cleanup
  echo "Finished. Exiting ..."    
  exit 1
}

function handle_error () {
  print_empty_lines 2
  echo "An error occurred."
  echo "Backing up files to folder ./$FOLDER_BACKUP."
  backup
  echo "Cleaning up files."
  cleanup
  echo "Exiting ..."    
  exit 1
}

trap 'handle_interrupt' INT
trap 'handle_error' ERR

print_empty_lines 5

###########################################
# Some preparation steps
###########################################

# Backing up current Terraform configuration files.
if ! backup > /dev/null 2>&1; then
  echo "An error occurred while backing up current configuration files."
else
  echo "Backing up current configuration files."
fi

if ! cleanup > /dev/null 2>&1; then
  echo "An error occurred while cleaning up current configuration files."
else
  echo "Cleaning up current configuration files."
fi

###########################################
# Create FILE_PROVIDERS
###########################################

if [ "$BACKEND_CONFIGURE" == true ]; then
  if [ -f "./$FOLDER_LAUNCHPAD/$FILE_BACKEND_LAUNCHPAD" ]
  then
    echo "Adding backend definition."
    echo "# Azure Backend Configuration for Terraform State File Management" >> $FILE_PROVIDERS
    echo "" >> $FILE_PROVIDERS
    cat ./$FOLDER_LAUNCHPAD/$FILE_BACKEND_LAUNCHPAD >> ./$FILE_PROVIDERS
    sed -i "s/\(key\s*=\s*\)[^ ]*/\1\"${BACKEND_STATE_FILENAME}\"/" ./$FILE_PROVIDERS
  else
    echo "No backend definition found in $FOLDER_LAUNCHPAD."
    echo "Attention! Creating empty backend definition in $FILE_PROVIDERS. Make sure to declare the backend in file $FILE_PROVIDERS."

cat <<EOF >> $FILE_PROVIDERS
# Terraform State File Backend Configuration"

terraform {
  backend "azurerm" {
    tenant_id = ""
    subscription_id = ""
    resource_group_name = ""
    storage_account_name = ""
    container_name = ""
    key = ""
  }
}
EOF

  fi
fi

AZURERM_LATEST_VERSION=$(curl -s -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/hashicorp/terraform-provider-azurerm/releases/latest | jq -r ".tag_name" | sed 's/v//g')

echo "Adding provider restrictions."
echo "" >> $FILE_PROVIDERS
echo "# Provider Versions and Restrictions" >> $FILE_PROVIDERS
cat <<EOF >> $FILE_PROVIDERS

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= $AZURERM_LATEST_VERSION"
    }
  }
}

# Azure Provider - Default

provider "azurerm" {
  features {}
}
EOF


###########################################
# variables for core
###########################################

echo "Adding core variables to variables file."

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

variable "default_location" {
  type        = string
  description = "If specified, will set the Azure region in which region bound resources will be deployed. Please see: https://azure.microsoft.com/en-gb/global-infrastructure/geographies/"
  default     = "$DEFAULT_LOCATION"
}
EOF


###########################################
# Create initial FILE_MAIN
###########################################

ES_VERSION=$(curl -s -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/Azure/terraform-azurerm-caf-enterprise-scale/releases/latest | jq -r ".tag_name" | sed 's/v//g')

echo "Adding module configuration to main file."

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

  # Core
  root_parent_id = data.azurerm_client_config.core.tenant_id
  root_id = var.root_id
  default_location = var.default_location
EOF


###########################################
# CONNECTIVITY
###########################################

if [ -n "$CONNECTIVITY_SUBSCRIPTION_ID" ]; then
  echo "Adding connectivity provider."
  sed -i 's/azurerm.connectivity = azurerm/azurerm.connectivity = azurerm.connectivity/' main.tf

  cat <<EOF >> $FILE_PROVIDERS

# Azure Provider - Connectivity

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = "$CONNECTIVITY_SUBSCRIPTION_ID"
  features {}
}
EOF

  echo "Adding connectivity data source."
  cat <<EOF >> tmp.txt
data "azurerm_client_config" "connectivity" {
  provider = azurerm.connectivity
}

EOF

  cat $FILE_MAIN >> tmp.txt
  mv tmp.txt $FILE_MAIN
    
  echo "Adding subscription_id_connectivity to main file."
  echo "" >> $FILE_MAIN
  echo "# Connectivity" >> $FILE_MAIN
  echo "subscription_id_connectivity = data.azurerm_client_config.connectivity.subscription_id" >> $FILE_MAIN
else
  echo "" >> $FILE_MAIN
  echo "# Connectivity" >> $FILE_MAIN
fi

if [ "$CONNECTIVITY_DEPLOY" == true ]; then
  echo "Adding deploy_connectivity_resources to variable file."
  cat <<EOF >> $FILE_VARIABLES

variable "deploy_connectivity_resources" {
  type        = bool
  description = "If set to true, will enable the \"Connectivity\" landing zone settings and add \"Connectivity\" resources into the current Subscription context."
  default     = true
}
EOF
else
  echo "Adding deploy_connectivity_resources to variable file."
  cat <<EOF >> $FILE_VARIABLES

variable "deploy_connectivity_resources" {
  type        = bool
  description = "If set to true, will enable the \"Connectivity\" landing zone settings and add \"Connectivity\" resources into the current Subscription context."
  default     = false
}
EOF
fi

echo "Adding deploy_connectivity_resources to main file."
echo "deploy_connectivity_resources = var.deploy_connectivity_resources" >> $FILE_MAIN

if [ "$CONNECTIVITY_CUSTOM" == true ]; then
  # Create FILE_LOCALS_CONNECTIVITY
  curl -s https://raw.githubusercontent.com/Azure/terraform-azurerm-caf-enterprise-scale/main/variables.tf > 1.txt
  sed -n '/variable "configure_connectivity_resources" {/,/^}/p' 1.txt > 2.txt
  sed -n '/  default = {/,/^  }/p' 2.txt > 1.txt
  sed -n '/    settings = {/,/^    }/p' 1.txt > 2.txt
  
  echo "Adding configure_connectivity_resources to locals."
  cat <<EOF > $FILE_LOCALS_CONNECTIVITY
locals {
  configure_connectivity_resources = {
EOF

  cat 2.txt >> $FILE_LOCALS_CONNECTIVITY

  cat <<EOF >> $FILE_LOCALS_CONNECTIVITY
  }
}
EOF
  rm 1.txt 2.txt
  echo "configure_connectivity_resources = local.configure_connectivity_resources" >> $FILE_MAIN
fi


###########################################
# MANAGEMENT
###########################################

if [ -n "$MANAGEMENT_SUBSCRIPTION_ID" ]; then
  echo "Adding management provider."
  sed -i 's/azurerm.management = azurerm/azurerm.management = azurerm.management/' main.tf

  cat <<EOF >> $FILE_PROVIDERS

# Azure Provider - Management

provider "azurerm" {
  alias           = "management"
  subscription_id = "$MANAGEMENT_SUBSCRIPTION_ID"
  features {}
}
EOF

  echo "Adding management data source."
  cat <<EOF >> tmp.txt
data "azurerm_client_config" "management" {
  provider = azurerm.management
}

EOF

  cat $FILE_MAIN >> tmp.txt
  mv tmp.txt $FILE_MAIN

  echo "" >> $FILE_MAIN
  echo "# Management" >> $FILE_MAIN
  echo "Adding subscription_id_management to main file."
  echo "subscription_id_management = data.azurerm_client_config.management.subscription_id" >> $FILE_MAIN
else
  echo "" >> $FILE_MAIN
  echo "# Management" >> $FILE_MAIN
fi

if [ "$MANAGEMENT_DEPLOY" == true ]; then
  echo "Adding deploy_management_resources to variable file."
  cat <<EOF >> $FILE_VARIABLES

variable "deploy_management_resources" {
  type        = bool
  description = "If set to true, will enable the \"Management\" landing zone settings and add \"Management\" resources into the current Subscription context."
  default     = true
}
EOF
else
  echo "Adding deploy_management_resources to variable file."
  cat <<EOF >> $FILE_VARIABLES

variable "deploy_management_resources" {
  type        = bool
  description = "If set to true, will enable the \"Management\" landing zone settings and add \"Management\" resources into the current Subscription context."
  default     = false
}
EOF
fi

echo "Adding deploy_management_resources to main file."
echo "deploy_management_resources = var.deploy_management_resources" >> $FILE_MAIN

if [ "$MANAGEMENT_CUSTOM" == true ]; then
  # Create FILE_LOCALS_MANAGEMENT
  curl -s https://raw.githubusercontent.com/Azure/terraform-azurerm-caf-enterprise-scale/main/variables.tf > 1.txt
  sed -n '/variable "configure_management_resources" {/,/^}/p' 1.txt > 2.txt
  sed -n '/  default = {/,/^  }/p' 2.txt > 1.txt
  sed -n '/    settings = {/,/^    }/p' 1.txt > 2.txt

  echo "Adding configure_management_resources to locals."
  cat <<EOF > $FILE_LOCALS_MANAGEMENT
locals {
  configure_management_resources = {
EOF

  cat 2.txt >> $FILE_LOCALS_MANAGEMENT

  cat <<EOF >> $FILE_LOCALS_MANAGEMENT
  }
}
EOF
  rm 1.txt 2.txt
  echo "configure_management_resources = local.configure_management_resources" >> $FILE_MAIN
fi


###########################################
# Custom Management Groups
###########################################

echo "" >> $FILE_MAIN

# Read the yaml file and convert it to JSON
YAML_FILE=$FILE_SETTINGS
JSON_FILE="settings.json"
yq eval -o=json "$YAML_FILE" > "$JSON_FILE"

# Loop through the custom management groups and map the values to the fields
echo "# Custom Management Groups" >> $FILE_MAIN
custom_landing_zones="custom_landing_zones = {\n"
for group in $(jq -r '.settings.custom_management_groups | keys[]' "$JSON_FILE"); do
  id=$(jq -r ".settings.custom_management_groups.$group.id" "$JSON_FILE")
  display_name=$(jq -r ".settings.custom_management_groups.$group.display_name" "$JSON_FILE")
  parent_id=$(jq -r ".settings.custom_management_groups.$group.parent_management_group_id" "$JSON_FILE")
  subscription_ids=$(jq -c ".settings.custom_management_groups.$group.subscription_ids" "$JSON_FILE")
  echo "Adding custom management group to main file."

  # Check if id is not null
  if [[ "$id" != null ]]; then
    if [[ "$id" == *"launchpad"* ]]; then
      custom_landing_zones+="  \"\${var.root_id}-$id\" = {\n"
      custom_landing_zones+="    display_name = \"$display_name\"\n"
      custom_landing_zones+="    parent_management_group_id = \"\${var.root_id}\"\n"
      custom_landing_zones+="    subscription_ids = $subscription_ids\n"
      custom_landing_zones+="    archetype_config = {\n"
      custom_landing_zones+="      archetype_id   = \"default_empty\"\n"
      custom_landing_zones+="      parameters     = {}\n"
      custom_landing_zones+="      access_control = {}\n"
      custom_landing_zones+="    }\n"
      custom_landing_zones+="  }\n"
    else
      custom_landing_zones+="  \"\${var.root_id}-$id\" = {\n"
      custom_landing_zones+="    display_name = \"\${upper(var.root_id)} $display_name\"\n"
      custom_landing_zones+="    parent_management_group_id = \"\${var.root_id}-$parent_id\"\n"
      custom_landing_zones+="    subscription_ids = $subscription_ids\n"
      custom_landing_zones+="    archetype_config = {\n"
      custom_landing_zones+="      archetype_id   = \"default_empty\"\n"
      custom_landing_zones+="      parameters     = {}\n"
      custom_landing_zones+="      access_control = {}\n"
      custom_landing_zones+="    }\n"
      custom_landing_zones+="  }\n"
    fi
  fi
done
custom_landing_zones+="}"

rm $JSON_FILE > /dev/null 2>&1
echo -e "$custom_landing_zones" >> $FILE_MAIN

###########################################
# Post steps
###########################################

# Add closing bracket to FILE_MAIN
echo "Adding closing bracket to main file."
echo "}" >> $FILE_MAIN

# Format all Terraform files
if ! terraform fmt > /dev/null 2>&1; then
  echo "An error occurred while formatting Terraform files. Please check all files for syntax errors."
else
  echo "Formatting Terraform files."
fi

print_empty_lines 3
echo -e '\e[1;32m##############################################\e[0m'
echo -e '\e[1;32m# ATTENTION! Before manually executing Terraform, e.g. terraform init, make sure you have set the following environment variables:\e[0m'
echo -e '\e[1;32m# export ARM_TENANT_ID="..." # The AAD tenant of your automation user.\e[0m'
echo -e '\e[1;32m# export ARM_CLIENT_ID="..." # The Client ID of your automation user.'
echo -e '\e[1;32m# export ARM_CLIENT_SECRET="..." # The Client Secret of your automation user.\e[0m'
echo -e '\e[1;32m# export ARM_SUBSCRIPTION_ID="..." # The Launchpad subscription ID.\e[0m'
echo -e '\e[1;32m# Terraform will use these values for authenticating to Azure, when reading the backend storage.\e[0m'
echo -e '\e[1;32m##############################################\e[0m'