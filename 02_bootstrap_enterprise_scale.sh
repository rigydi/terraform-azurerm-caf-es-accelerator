#!/usr/bin/env bash

###########################################
# Variables
###########################################

FILE_PROVIDERS="terraform.tf"
FILE_MAIN="main.tf"
FILE_VARIABLES="variables.tf"
FILE_TFVARS="terraform.tfvars"
FILE_SETTINGS="bootstrap.yaml"
FILE_BACKEND_BRIDGEHEAD="backend.tf"
FILE_LOCALS_CONNECTIVITY="settings.connectivity.tf"
FILE_LOCALS_MANAGEMENT="settings.management.tf"
FILE_LOCALS_IDENTITY="settings.identity.tf"
FILE_SECRETS="secrets.tf"

# Read the yaml file and convert it to JSON
YAML_FILE=$FILE_SETTINGS
JSON_FILE="bootstrap.json"
yq eval -o=json "$YAML_FILE" > "$JSON_FILE"

DIRECTORY_ENTERPRISE_SCALE="02_enterprisescale"
DIRECTORY_BACKUP="backup"
DIRECTORY_BRIDGEHEAD="01_bridgehead"
DIRECTORY_LIBRARY="lib"
DIRECTORY_POLICY_ASSIGNMENTS="$DIRECTORY_LIBRARY/policy_assignments"

BACKEND_STATE_FILENAME="terraform-enterprise-scale.tfstate"

ROOT_ID=$(yq '.settings.enterprisescale.core.root_id' $FILE_SETTINGS)
ROOT_NAME=$(yq '.settings.enterprisescale.core.root_name' $FILE_SETTINGS)
DEFAULT_LOCATION=$(yq '.settings.bridgehead.location' $FILE_SETTINGS)

CONNECTIVITY_DEPLOY=$(yq '.settings.enterprisescale.connectivity.deploy' $FILE_SETTINGS)
CONNECTIVITY_SUBSCRIPTION_ID=$(yq '.settings.enterprisescale.connectivity.subscription_id' $FILE_SETTINGS)
CONNECTIVITY_CUSTOM=$(yq '.settings.enterprisescale.connectivity.customize' $FILE_SETTINGS)
CONNECTIVITY_DATASOURCE_NAME="$(grep name $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS | cut -d'"' -f2 | grep -i connectivity)"

MANAGEMENT_DEPLOY=$(yq '.settings.enterprisescale.management.deploy' $FILE_SETTINGS)
MANAGEMENT_SUBSCRIPTION_ID=$(yq '.settings.enterprisescale.management.subscription_id' $FILE_SETTINGS)
MANAGEMENT_CUSTOM=$(yq '.settings.enterprisescale.management.customize' $FILE_SETTINGS)
MANAGEMENT_DATASOURCE_NAME="$(grep name $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS | cut -d'"' -f2 | grep -i management)"

MANAGEMENT_GROUP_BUILTIN_CORP=$(yq '.settings.enterprisescale.additional_builtin_management_groups.corp' $FILE_SETTINGS)
MANAGEMENT_GROUP_BUILTIN_ONLINE=$(yq '.settings.enterprisescale.additional_builtin_management_groups.online' $FILE_SETTINGS)
MANAGEMENT_GROUP_BUILTIN_SAP=$(yq '.settings.enterprisescale.additional_builtin_management_groups.sap' $FILE_SETTINGS)

IDENTITY_DEPLOY=$(yq '.settings.enterprisescale.identity.deploy' $FILE_SETTINGS)
IDENTITY_SUBSCRIPTION_ID=$(yq '.settings.enterprisescale.identity.subscription_id' $FILE_SETTINGS)
IDENTITY_CUSTOM=$(yq '.settings.enterprisescale.identity.customize' $FILE_SETTINGS)
IDENTITY_DATASOURCE_NAME="$(grep name $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS | cut -d'"' -f2 | grep -i identity)"

ES_LATEST_VERSION_TAG=$(curl -s -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/Azure/terraform-azurerm-caf-enterprise-scale/releases/latest | jq -r ".tag_name")
ES_LATEST_VERSION=$(echo $ES_LATEST_VERSION_TAG | sed 's/v//g')

ES_LATEST_VERSION="3.3.0"
ES_LATEST_VERSION_TAG="v3.3.0"

DATE=$(date '+%Y%m%d%H%M%S')

KEY_VAULT_NAME=$(terraform -chdir=$DIRECTORY_BRIDGEHEAD output key_vault_name)
RESOURCE_GROUP_NAME=$(terraform -chdir=$DIRECTORY_BRIDGEHEAD output resource_group_name)

mkdir -p $DIRECTORY_ENTERPRISE_SCALE

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
  rm -rf $DIRECTORY_ENTERPRISE_SCALE/* > /dev/null 2>&1
}

function backup () {
  array_backup=($DIRECTORY_ENTERPRISE_SCALE)
  mkdir -p ./$DIRECTORY_BACKUP/$DATE > /dev/null 2>&1
  for element in "${array_backup[@]}"
  do
    if [[ -e $element ]]
    then
      echo "Backing up: $element"
      cp -a "$element" ./$DIRECTORY_BACKUP/$DATE/ > /dev/null 2>&1
    else
      echo "$element is not existing. No backup necessary."
    fi
  done
}

function handle_interrupt () {
  print_empty_lines 2
  echo "Backing up files to folder ./$DIRECTORY_BACKUP."
  backup
  echo "Cleaning up files."
  cleanup
  echo "Finished. Exiting ..."    
  exit 1
}

function handle_error () {
  print_empty_lines 2
  echo "An error occurred."
  echo "Backing up files to folder ./$DIRECTORY_BACKUP."
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


if [ -f "./$DIRECTORY_BRIDGEHEAD/$FILE_BACKEND_BRIDGEHEAD" ]
then
  echo "Adding backend definition."
  echo "# Azure Backend Configuration for Terraform State File Management" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS
  echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS
  cat ./$DIRECTORY_BRIDGEHEAD/$FILE_BACKEND_BRIDGEHEAD >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS
  sed -i "s/\(key\s*=\s*\)[^ ]*/\1\"${BACKEND_STATE_FILENAME}\"/" $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS
else
  echo "No backend definition found in $DIRECTORY_BRIDGEHEAD."
  echo "Attention! Creating empty backend definition in $FILE_PROVIDERS. Make sure to declare the backend in file $FILE_PROVIDERS."

cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS
# Terraform State File Backend Configuration"

terraform {
backend "azurerm" {
  resource_group_name = ""
  storage_account_name = ""
  container_name = ""
  key = ""
}
}
EOF
fi

AZURERM_LATEST_VERSION=$(curl -s -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/hashicorp/terraform-provider-azurerm/releases/latest | jq -r ".tag_name" | sed 's/v//g')

echo "Adding provider restrictions."
echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS
echo "# Provider Versions and Restrictions" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS
cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS

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

cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES
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

echo "Adding module configuration to main file."

cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
data "azurerm_key_vault" "this" {
  name                = $KEY_VAULT_NAME
  resource_group_name = $RESOURCE_GROUP_NAME
}

data "azurerm_client_config" "core" {}

module "enterprise_scale" {
  source  = "Azure/caf-enterprise-scale/azurerm"
  version = "$ES_LATEST_VERSION"

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
  sed -i 's/azurerm.connectivity = azurerm/azurerm.connectivity = azurerm.connectivity/' $DIRECTORY_ENTERPRISE_SCALE/main.tf

  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS

# Azure Provider - Connectivity

data "azurerm_key_vault_secret" "$CONNECTIVITY_DATASOURCE_NAME" {
  name         = "$CONNECTIVITY_DATASOURCE_NAME"
  key_vault_id = data.azurerm_key_vault.this.id
}

provider "azurerm" {
  alias           = "connectivity"
  subscription_id = data.azurerm_key_vault_secret.$CONNECTIVITY_DATASOURCE_NAME.value
  features {}
}
EOF

  echo "Adding connectivity data source."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/tmp.txt
data "azurerm_client_config" "connectivity" {
  provider = azurerm.connectivity
}

EOF

  cat $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN >> $DIRECTORY_ENTERPRISE_SCALE/tmp.txt
  mv $DIRECTORY_ENTERPRISE_SCALE/tmp.txt $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
    
  echo "Adding subscription_id_connectivity to main file."
  echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "# Connectivity" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "subscription_id_connectivity = data.azurerm_client_config.connectivity.subscription_id" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
else
  echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "# Connectivity" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
fi

if [ "$CONNECTIVITY_DEPLOY" == true ]; then
  echo "Adding deploy_connectivity_resources to variable file."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_connectivity_resources" {
  type        = bool
  description = "If set to true, will enable the \"Connectivity\" landing zone settings and add \"Connectivity\" resources into the current Subscription context."
  default     = true
}
EOF
else
  echo "Adding deploy_connectivity_resources to variable file."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_connectivity_resources" {
  type        = bool
  description = "If set to true, will enable the \"Connectivity\" landing zone settings and add \"Connectivity\" resources into the current Subscription context."
  default     = false
}
EOF
fi

echo "Adding deploy_connectivity_resources to main file."
echo "deploy_connectivity_resources = var.deploy_connectivity_resources" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

if [ "$CONNECTIVITY_CUSTOM" == true ]; then
  # Create FILE_LOCALS_CONNECTIVITY
  curl -s https://raw.githubusercontent.com/Azure/terraform-azurerm-caf-enterprise-scale/$ES_LATEST_VERSION_TAG/variables.tf > $DIRECTORY_ENTERPRISE_SCALE/1.txt
  sed -n '/variable "configure_connectivity_resources" {/,/^}/p' $DIRECTORY_ENTERPRISE_SCALE/1.txt > $DIRECTORY_ENTERPRISE_SCALE/2.txt
  sed -n '/  default = {/,/^  }/p' $DIRECTORY_ENTERPRISE_SCALE/2.txt > $DIRECTORY_ENTERPRISE_SCALE/1.txt
  sed -n '/    settings = {/,/^    }/p' $DIRECTORY_ENTERPRISE_SCALE/1.txt > $DIRECTORY_ENTERPRISE_SCALE/2.txt
  
  echo "Adding configure_connectivity_resources to locals."
  cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_CONNECTIVITY
locals {
  configure_connectivity_resources = {
EOF

  cat $DIRECTORY_ENTERPRISE_SCALE/2.txt >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_CONNECTIVITY

  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_CONNECTIVITY
  }
}
EOF
  rm $DIRECTORY_ENTERPRISE_SCALE/1.txt $DIRECTORY_ENTERPRISE_SCALE/2.txt
  echo "configure_connectivity_resources = local.configure_connectivity_resources" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
fi


###########################################
# MANAGEMENT
###########################################

if [ -n "$MANAGEMENT_SUBSCRIPTION_ID" ]; then
  echo "Adding management provider."
  sed -i 's/azurerm.management = azurerm/azurerm.management = azurerm.management/' $DIRECTORY_ENTERPRISE_SCALE/main.tf

  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS

# Azure Provider - Management

data "azurerm_key_vault_secret" "$MANAGEMENT_DATASOURCE_NAME" {
  name         = "$MANAGEMENT_DATASOURCE_NAME"
  key_vault_id = data.azurerm_key_vault.this.id
}

provider "azurerm" {
  alias           = "management"
  subscription_id = data.azurerm_key_vault_secret.$MANAGEMENT_DATASOURCE_NAME.value
  features {}
}
EOF

  echo "Adding management data source."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/tmp.txt
data "azurerm_client_config" "management" {
  provider = azurerm.management
}

EOF

  cat $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN >> $DIRECTORY_ENTERPRISE_SCALE/tmp.txt
  mv $DIRECTORY_ENTERPRISE_SCALE/tmp.txt $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

  echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "# Management" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "Adding subscription_id_management to main file."
  echo "subscription_id_management = data.azurerm_client_config.management.subscription_id" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
else
  echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "# Management" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
fi

if [ "$MANAGEMENT_DEPLOY" == true ]; then
  echo "Adding deploy_management_resources to variable file."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_management_resources" {
  type        = bool
  description = "If set to true, will enable the \"Management\" landing zone settings and add \"Management\" resources into the current Subscription context."
  default     = true
}
EOF
else
  echo "Adding deploy_management_resources to variable file."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_management_resources" {
  type        = bool
  description = "If set to true, will enable the \"Management\" landing zone settings and add \"Management\" resources into the current Subscription context."
  default     = false
}
EOF
fi

echo "Adding deploy_management_resources to main file."
echo "deploy_management_resources = var.deploy_management_resources" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

if [ "$MANAGEMENT_CUSTOM" == true ]; then
  # Create FILE_LOCALS_MANAGEMENT
  curl -s https://raw.githubusercontent.com/Azure/terraform-azurerm-caf-enterprise-scale/$ES_LATEST_VERSION_TAG/variables.tf > $DIRECTORY_ENTERPRISE_SCALE/1.txt
  sed -n '/variable "configure_management_resources" {/,/^}/p' $DIRECTORY_ENTERPRISE_SCALE/1.txt > $DIRECTORY_ENTERPRISE_SCALE/2.txt
  sed -n '/  default = {/,/^  }/p' $DIRECTORY_ENTERPRISE_SCALE/2.txt > $DIRECTORY_ENTERPRISE_SCALE/1.txt
  sed -n '/    settings = {/,/^    }/p' $DIRECTORY_ENTERPRISE_SCALE/1.txt > $DIRECTORY_ENTERPRISE_SCALE/2.txt

  echo "Adding configure_management_resources to locals."
  cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_MANAGEMENT
locals {
  configure_management_resources = {
EOF

  cat $DIRECTORY_ENTERPRISE_SCALE/2.txt >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_MANAGEMENT

  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_MANAGEMENT
  }
}
EOF
  rm $DIRECTORY_ENTERPRISE_SCALE/1.txt $DIRECTORY_ENTERPRISE_SCALE/2.txt
  echo "configure_management_resources = local.configure_management_resources" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
fi

###########################################
# Identity
###########################################

if [ -n "$IDENTITY_SUBSCRIPTION_ID" ]; then
  echo "Adding identity provider."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS

# Azure Provider - Identity

data "azurerm_key_vault_secret" "$IDENTITY_DATASOURCE_NAME" {
  name         = "$IDENTITY_DATASOURCE_NAME"
  key_vault_id = data.azurerm_key_vault.this.id
}

provider "azurerm" {
  alias           = "identity"
  subscription_id = data.azurerm_key_vault_secret.$IDENTITY_DATASOURCE_NAME.value
  features {}
}
EOF

  echo "Adding identity data source."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/tmp.txt
data "azurerm_client_config" "identity" {
  provider = azurerm.identity
}

EOF

  cat $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN >> $DIRECTORY_ENTERPRISE_SCALE/tmp.txt
  mv $DIRECTORY_ENTERPRISE_SCALE/tmp.txt $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

  echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "# Identity" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "Adding subscription_id_identity to main file."
  echo "subscription_id_identity = data.azurerm_client_config.identity.subscription_id" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
else
  echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "# Identity" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
fi

if [ "$IDENTITY_DEPLOY" == true ]; then
  echo "Adding deploy_identity_resources to variable file."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_identity_resources" {
  type        = bool
  description = "If set to true, will enable the \"Identity\" landing zone settings."
  default     = true
}
EOF
else
  echo "Adding deploy_identity_resources to variable file."
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_identity_resources" {
  type        = bool
  description = "If set to true, will enable the \"Identity\" landing zone settings."
  default     = false
}
EOF
fi

echo "Adding deploy_identity_resources to main file."
echo "deploy_identity_resources = var.deploy_identity_resources" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

if [ "$IDENTITY_CUSTOM" == true ]; then
  # Create FILE_LOCALS_IDENTITY
  curl -s https://raw.githubusercontent.com/Azure/terraform-azurerm-caf-enterprise-scale/$ES_LATEST_VERSION_TAG/variables.tf > $DIRECTORY_ENTERPRISE_SCALE/1.txt
  sed -n '/variable "configure_identity_resources" {/,/^}/p' $DIRECTORY_ENTERPRISE_SCALE/1.txt > $DIRECTORY_ENTERPRISE_SCALE/2.txt
  sed -n '/  default = {/,/^  }/p' $DIRECTORY_ENTERPRISE_SCALE/2.txt > $DIRECTORY_ENTERPRISE_SCALE/1.txt
  sed -n '/    settings = {/,/^    }/p' $DIRECTORY_ENTERPRISE_SCALE/1.txt > $DIRECTORY_ENTERPRISE_SCALE/2.txt

  echo "Adding configure_identity_resources to locals."
  cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_IDENTITY
locals {
  configure_identity_resources = {
EOF

  cat $DIRECTORY_ENTERPRISE_SCALE/2.txt >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_IDENTITY

  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_LOCALS_IDENTITY
  }
}
EOF
  rm $DIRECTORY_ENTERPRISE_SCALE/1.txt $DIRECTORY_ENTERPRISE_SCALE/2.txt
  echo "configure_identity_resources = local.configure_identity_resources" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
fi

###########################################
# Additional Built-In Management Groups
###########################################

if [[ "$MANAGEMENT_GROUP_BUILTIN_CORP" == "true" || "$MANAGEMENT_GROUP_BUILTIN_ONLINE" == "true" || "$MANAGEMENT_GROUP_BUILTIN_SAP" == "true" ]]
then
  echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
  echo "# Additional Built-In Management Groups" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
fi

if [ "$MANAGEMENT_GROUP_BUILTIN_CORP" == "true" ]
then
  echo "Adding CORP Management Group to main file."
  echo "deploy_corp_landing_zones = var.deploy_corp_landing_zones" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_corp_landing_zones" {
  type        = bool
  description = "If set to true, module will deploy the \"Corp\" Management Group, including \"out of the box\" policies and roles."
  default     = true
}
EOF
fi

if [ "$MANAGEMENT_GROUP_BUILTIN_ONLINE" == "true" ]
then
  echo "Adding ONLINE Management Group to main file."
  echo "deploy_online_landing_zones = var.deploy_online_landing_zones" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_online_landing_zones" {
  type        = bool
  description = "If set to true, module will deploy the \"Online\" Management Group, including \"out of the box\" policies and roles."
  default     = true
}
EOF
fi

if [ "$MANAGEMENT_GROUP_BUILTIN_SAP" == "true" ]
then
  echo "Adding SAP Management Group to main file."
  echo "deploy_sap_landing_zones = var.deploy_sap_landing_zones" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_VARIABLES

variable "deploy_sap_landing_zones" {
  type        = bool
  description = "If set to true, module will deploy the \"SAP\" Management Group, including \"out of the box\" policies and roles."
  default     = true
}
EOF
fi

###########################################
# Custom Management Groups
###########################################

echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

# Loop through the custom management groups and map the values to the fields
echo "# Custom Management Groups" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
custom_landing_zones="custom_landing_zones = {\n"
for group in $(jq -r '.settings.enterprisescale.custom_management_groups | keys[]' "$JSON_FILE"); do
  id=$(jq -r ".settings.enterprisescale.custom_management_groups.$group.id" "$JSON_FILE")
  display_name=$(jq -r ".settings.enterprisescale.custom_management_groups.$group.display_name" "$JSON_FILE")
  parent_id=$(jq -r ".settings.enterprisescale.custom_management_groups.$group.parent_management_group_id" "$JSON_FILE")
  #subscription_ids=$(jq -c ".settings.enterprisescale.custom_management_groups.$group.subscription_ids" "$JSON_FILE")
  subscription_ids_datasource=("[ "$(cat $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS | grep -i name | grep -i $id | awk '{print "data.azurerm_key_vault_secret."$3".value"}' | tr -d '"' | tr '\n' ',' | sed 's/,$/\n]/'))
  subscription_ids=($(cat $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS | grep -i name | grep -i $id | awk '{print $3}' | tr -d '"' | tr '\n' ' '))
  #subscription_ids=($(cat $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS | grep -i name | grep -i $id | awk '{print $3}' | tr '\n' ' '))
  
  echo "Adding additional subscription_ids as data source secrets."
  for subscription_id in ${subscription_ids[@]}; do
  cat <<EOF >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_PROVIDERS

data "azurerm_key_vault_secret" "$subscription_id" {
  name         = "$subscription_id"
  key_vault_id = data.azurerm_key_vault.this.id
}
EOF
  done

  echo "Adding custom management group to main file."

  # Check if id is not null
  if [[ "$id" != null ]]; then
    if [[ "$id" == *"bridgehead"* ]]; then
      custom_landing_zones+="  \"\${var.root_id}-$id\" = {\n"
      custom_landing_zones+="    display_name = \"$display_name\"\n"
      custom_landing_zones+="    parent_management_group_id = \"\${var.root_id}\"\n"
      custom_landing_zones+="    subscription_ids = ${subscription_ids_datasource[@]}\n"
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
      custom_landing_zones+="    subscription_ids = ${subscription_ids_datasource[@]}\n"
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

echo -e "$custom_landing_zones" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

###########################################
# Policies
###########################################

echo "" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
echo "library_path = \"\${path.root}/lib\"" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN
mkdir -p $DIRECTORY_ENTERPRISE_SCALE/$DIRECTORY_POLICY_ASSIGNMENTS

# Read the JSON file and extract the policies and management_group_id
policies=$(jq -r '.settings.enterprisescale.policies | keys[]' $JSON_FILE)
mgmt_group_ids=$(jq -r '.settings.enterprisescale.policies[].management_group_id' $JSON_FILE)

# Loop over the management_group_id
while read -r mgmt_group_id; do
  # Create the file name
  file_name="archetype_extension_es_${mgmt_group_id}.tmpl.json"

  # Get the policies for this management_group_id that have assign set to true
  mgmt_policies=$(jq -r --arg mgmt_group_id "$mgmt_group_id" \
    '.settings.enterprisescale.policies | to_entries[] | select(.value.management_group_id == $mgmt_group_id and .value.assign == true) | .key' $JSON_FILE)

  # Check if there are any policies to process
  if [ -n "$mgmt_policies" ]; then
    # Create the JSON content
    json_content=$(jq -n --arg mgmt_group_id "$mgmt_group_id" --argjson policy_assignments "$(echo "$mgmt_policies" | jq -R . | jq -cs .)" \
      '{
        ("extend_es_\($mgmt_group_id)"): {
          policy_assignments: $policy_assignments,
          policy_definitions: [],
          policy_set_definitions: [],
          role_definitions: [],
          archetype_config: {
            access_control: {}
          }
        }
      }')

    # Write the JSON content to the file
    echo "$json_content" > $DIRECTORY_ENTERPRISE_SCALE/$DIRECTORY_LIBRARY/"$file_name"
  fi
done <<< "$mgmt_group_ids" | sort -u

###########################################
# Create Repository of Policy Assignments
###########################################
######################
# Azure Security Benchmark
######################
cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$DIRECTORY_POLICY_ASSIGNMENTS/policy_assignment_azure_security_benchmark.json
{
    "name": "Azure_Security_Benchmark",
    "type": "Microsoft.Authorization/policyAssignments",
    "apiVersion": "2019-09-01",
    "properties": {
        "description": "The Azure Security Benchmark initiative represents the policies and controls implementing security recommendations defined in Azure Security Benchmark v3, see https://aka.ms/azsecbm. This also serves as the Microsoft Defender for Cloud default policy initiative. You can directly assign this initiative, or manage its policies and compliance results within Microsoft Defender for Cloud.",
        "displayName": "Azure Security Benchmark",
        "notScopes": [],
        "parameters": {
        },
        "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8",
        "nonComplianceMessages": [
          {
            "message": "Azure Security Benchmark policy controls {enforcementMode} be enforced."
          }
        ],
        "scope": "${current_scope_resource_id}",
        "enforcementMode": null
    },
    "location": "\${default_location}",
    "identity": {
        "type": "SystemAssigned"
    }
}
EOF

######################
# CIS_Microsoft_Azure_Foundations_Benchmark_v1.4.0
######################
cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$DIRECTORY_POLICY_ASSIGNMENTS/policy_assignment_cis.json
{
    "name": "CIS",
    "type": "Microsoft.Authorization/policyAssignments",
    "apiVersion": "2019-09-01",
    "properties": {
        "description": "The Center for Internet Security (CIS) is a nonprofit entity whose mission is to 'identify, develop, validate, promote, and sustain best practice solutions for cyberdefense.' CIS benchmarks are configuration baselines and best practices for securely configuring a system. These policies address a subset of CIS Microsoft Azure Foundations Benchmark v1.4.0 controls. For more information, visit https://aka.ms/cisazure130-initiative.",
        "displayName": "CIS Microsoft Azure Foundations Benchmark v1.4.0",
        "notScopes": [],
        "parameters": {
        },
        "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/c3f5c4d9-9a1d-4a99-85c0-7f93e384d5c5",
        "nonComplianceMessages": [
          {
            "message": "CIS Microsoft Azure Foundations Benchmark v1.4.0 policy controls {enforcementMode} be enforced."
          }
        ],
        "scope": "${current_scope_resource_id}",
        "enforcementMode": null
    },
    "location": "\${default_location}",
    "identity": {
        "type": "SystemAssigned"
    }
}
EOF

######################
# ISO_27001_2013
######################
cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$DIRECTORY_POLICY_ASSIGNMENTS/policy_assignment_iso_27001_2013.json
{
    "name": "ISO_27001_2013",
    "type": "Microsoft.Authorization/policyAssignments",
    "apiVersion": "2019-09-01",
    "properties": {
        "description": "The International Organization for Standardization (ISO) 27001 standard provides requirements for establishing, implementing, maintaining, and continuously improving an Information Security Management System (ISMS). These policies address a subset of ISO 27001:2013 controls. Additional policies will be added in upcoming releases. For more information, visit https://aka.ms/iso27001-init.",
        "displayName": "ISO 27001:2013",
        "notScopes": [],
        "parameters": {
        },
        "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/89c6cddc-1c73-4ac1-b19c-54d1a15a42f2",
        "nonComplianceMessages": [
          {
            "message": "ISO 27001:2013 policy controls {enforcementMode} be enforced."
          }
        ],
        "scope": "${current_scope_resource_id}",
        "enforcementMode": null
    },
    "location": "\${default_location}",
    "identity": {
        "type": "SystemAssigned"
    }
}
EOF

######################
# ISO_27001_2013
######################
cat <<EOF > $DIRECTORY_ENTERPRISE_SCALE/$DIRECTORY_POLICY_ASSIGNMENTS/policy_assignment_nist.json
{
    "name": "NIST_SP_800_53_Rev_5",
    "type": "Microsoft.Authorization/policyAssignments",
    "apiVersion": "2019-09-01",
    "properties": {
        "description": "National Institute of Standards and Technology (NIST) SP 800-53 Rev. 5 provides a standardized approach for assessing, monitoring and authorizing cloud computing products and services to manage information security risk. These policies address a subset of NIST SP 800-53 R5 controls. Additional policies will be added in upcoming releases. For more information, visit https://aka.ms/nist800-53r5-initiative.",
        "displayName": "NIST SP 800-53 Rev. 5",
        "notScopes": [],
        "parameters": {
        },
        "policyDefinitionId": "/providers/Microsoft.Authorization/policySetDefinitions/179d1daa-458f-4e47-8086-2a68d0d6c38f",
        "nonComplianceMessages": [
          {
            "message": "NIST SP 800-53 Rev. 5 policy controls {enforcementMode} be enforced."
          }
        ],
        "scope": "${current_scope_resource_id}",
        "enforcementMode": null
    },
    "location": "\${default_location}",
    "identity": {
        "type": "SystemAssigned"
    }
}
EOF

###########################################
# Post steps
###########################################

# Add closing bracket to FILE_MAIN
echo "Adding closing bracket to main file."
echo "}" >> $DIRECTORY_ENTERPRISE_SCALE/$FILE_MAIN

rm $JSON_FILE > /dev/null 2>&1

# Format all Terraform files
if ! terraform -chdir=$DIRECTORY_ENTERPRISE_SCALE fmt > /dev/null 2>&1; then
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
echo -e '\e[1;32m# export ARM_SUBSCRIPTION_ID="..." # The Bridgehead subscription ID.\e[0m'
echo -e '\e[1;32m# Terraform will use these values for authenticating to Azure, when reading the backend storage.\e[0m'
echo -e '\e[1;32m##############################################\e[0m'
print_empty_lines 3