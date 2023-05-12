#!/usr/bin/env bash

TEMP=$(getopt -o '' --long client_id:,client_secret:,tenant_id:,subscription_id:,environment: -- "$@")
eval set -- "$TEMP"

while true; do
  case "$1" in
    --client_id)
      ARM_CLIENT_ID="$2"
      shift 2;;
    --client_secret)
      ARM_CLIENT_SECRET="$2"
      shift 2;;
    --tenant_id)
      ARM_TENANT_ID="$2"
      shift 2;;
    --subscription_id)
      ARM_SUBSCRIPTION_ID="$2"
      shift 2;;
    --environment)
      ENVIRONMENT="$2"
      shift 2;;
    --)
      shift
      break;;
    *)
      echo "Invalid option: $1" >&2
      exit 1;;
  esac
done


if [[ -z "${ARM_CLIENT_ID}" || -z "${ARM_CLIENT_SECRET}" || -z "${ARM_TENANT_ID}" || -z "${ARM_SUBSCRIPTION_ID}" || -z "${ENVIRONMENT}" ]]; then
  echo "Error running shell script. Following input is required: --client_id <Service Principal Client ID> --client_secret <Service Principal Client Secret> --tenant_id <AAD Tenant ID --subscription_id <Azure Subscription ID> --environment <e.g. dev, stage, prod>" >&2
  exit 1
fi

FILE_VARIABLES="variables.tf"
FILE_TFVARS="terraform-$ENVIRONMENT.tfvars"
FILE_SETTINGS="bootstrap.yaml"
FILE_BACKEND="backend.tf"
FILE_OUTPUTS="outputs.tf"
FILE_PROVIDERS="terraform.tf"
FILE_MAIN="main.tf"
FILE_SECRETS="secrets.tf"

DIRECTORY_BRIDGEHEAD="01_bridgehead"

BASENAME="bridgehead-$ENVIRONMENT"
RANDOM_LENGTH=5
LOCATION=$(yq '.settings.bridgehead.location' $FILE_SETTINGS)
ACCOUNT_TIER=$(yq '.settings.bridgehead.account_tier' $FILE_SETTINGS)
ACCOUNT_REPLICATION_TYPE=$(yq '.settings.bridgehead.account_replication_type' $FILE_SETTINGS)

CONNECTIVITY_SUBSCRIPTION_ID=$(yq '.settings.enterprisescale.connectivity.subscription_id' $FILE_SETTINGS)
MANAGEMENT_SUBSCRIPTION_ID=$(yq '.settings.enterprisescale.management.subscription_id' $FILE_SETTINGS)
IDENTITY_SUBSCRIPTION_ID=$(yq '.settings.enterprisescale.identity.subscription_id' $FILE_SETTINGS)

AZURERM_LATEST_VERSION=$(curl -s -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/hashicorp/terraform-provider-azurerm/releases/latest | jq -r ".tag_name" | sed 's/v//g')

YAML_FILE=$FILE_SETTINGS
JSON_FILE="bootstrap.json"
yq eval -o=json "$YAML_FILE" > "$JSON_FILE"

###########################################
# Functions
###########################################

function print_empty_lines() {
  for (( i=1; i<=$1; i++ ))
  do
    echo ""
  done
}

function handle_interrupt () {
  print_empty_lines 1
  echo "Finished. Exiting ..."    
  exit 1
}

function handle_error () {
  print_empty_lines 1
  echo "An error occurred. Exiting ..."  
  exit 1
}

trap 'handle_interrupt' INT
trap 'handle_error' ERR

print_empty_lines 1

###########################################
# Verify if Input exists
###########################################

if [ -z "$BASENAME" ]; then
  print_empty_lines 1
  echo "BASENAME not specified."
  exit 1
fi

if [ -z "$RANDOM_LENGTH" ]; then
  print_empty_lines 1
  echo "RANDOM_LENGTH not specified."
  exit 1
fi

if [ -z "$LOCATION" ]; then
  print_empty_lines 1
  echo "LOCATION not specified."
  exit 1
fi

if [ -z "$ACCOUNT_TIER" ]; then
  print_empty_lines 1
  echo "ACCOUNT_TIER not specified."
  exit 1
fi

if [ -z "$ACCOUNT_REPLICATION_TYPE" ]; then
  print_empty_lines 1
  echo "ACCOUNT_REPLICATION_TYPE not specified."
  exit 1
fi

if [ -z "$ARM_CLIENT_ID" ]; then
  print_empty_lines 1
  echo "ARM_CLIENT_ID not specified. Please run the script with option flags: -i <Service Principal Client ID> -s <Service Principal Secret>"
  exit 1
fi

if [ -z "$ARM_CLIENT_SECRET" ]; then
  print_empty_lines 1
  echo "ARM_CLIENT_SECRET not specified. Please run the script with option flags: -i <Service Principal Client ID> -s <Service Principal Secret>"
  exit 1
fi

###########################################
# Bridgehead Directory
###########################################

mkdir -p ./$DIRECTORY_BRIDGEHEAD

###########################################
# Bridgehead Outputs File
###########################################

echo "Creating $FILE_OUTPUTS."
cat <<EOF > $DIRECTORY_BRIDGEHEAD/$FILE_OUTPUTS
output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "container_name" {
  value = azurerm_storage_container.this.name
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}
EOF

###########################################
# Bridgehead Providers File
###########################################

echo "Creating $FILE_PROVIDERS."
cat <<EOF > $DIRECTORY_BRIDGEHEAD/$FILE_PROVIDERS
terraform {
  required_version = "~> 1.3"
  required_providers {
    azurerm = "= $AZURERM_LATEST_VERSION" # https://registry.terraform.io/providers/hashicorp/azurerm/latest
    azurecaf = {
      source  = "aztfmod/azurecaf" # https://registry.terraform.io/providers/aztfmod/azurecaf/latest/docs
      version = "~> 1.2"
    }
  }
}

provider "azurerm" {
  features {}
}
EOF

###########################################
# Bridgehead Variables File
###########################################

echo "Creating $FILE_VARIABLES."
cat <<EOF > $DIRECTORY_BRIDGEHEAD/$FILE_VARIABLES
variable "tenant_id" {
  description = "The Azure Active Directory tenant ID."
  type        = string
  sensitive   = true
  default     = ""
}

variable "basename" {
  description = "The string for naming all Azure resources."
  type        = string
}

variable "random_length" {
  description = "A random suffix string added to each resource name."
  type        = number
  default     = $RANDOM_LENGTH
}

variable "location" {
  description = "Defines the region in which the resources will be deployed, e.g. westeurope."
  type        = string
  default     = "$LOCATION"

  validation {
    condition     = can(regex("^((east|west|central|north|south|switzerland)?(us|europe|asia|australia|north))$", var.location))
    error_message = "Invalid Azure region."
  }
}

variable "account_tier" {
  description = "Defines the tier of this storage account. Valid options are Standard and Premium. For BlockBlobStorage and FileStorage accounts only Premium is valid. Changing this forces a new resource to be created."
  type        = string
  default     = "$ACCOUNT_TIER"

  validation {
    condition     = can(regex("^((Standard|Premium))$", var.account_tier))
    error_message = "Invalid Azure storage account tier."
  }
}

variable "account_replication_type" {
  description = "Defines the type of replication to use for this storage account. Valid options are LRS, GRS, RAGRS, ZRS, GZRS and RAGZRS."
  type        = string
  default     = "$ACCOUNT_REPLICATION_TYPE"

  validation {
    condition     = can(regex("^((LRS|GRS|RAGRS|ZRS|GZRS|RAGZRS))$", var.account_replication_type))
    error_message = "Invalid Azure storage account replication type."
  }
}

variable "keyvault_sku_name" {
  description = "The Name of the SKU used for this Key Vault. Possible values are standard and premium."
  type        = string
  default     = "standard"

  validation {
    condition     = can(regex("^((standard|premium))$", var.keyvault_sku_name))
    error_message = "Invalid Azure key vault sku. Should be standard or premium."
  }
}
EOF

if [ -n "$CONNECTIVITY_SUBSCRIPTION_ID" ]; then
  echo "Adding subscription_id_connectivity as variable to $FILE_VARIABLES."
  cat <<EOF >> $DIRECTORY_BRIDGEHEAD/$FILE_VARIABLES

variable "subscription_id_connectivity" {
  description = "The Azure subscription ID of enterprise scale connectivity."
  type        = string
  sensitive   = true
  default     = ""
}
EOF
fi

if [ -n "$MANAGEMENT_SUBSCRIPTION_ID" ]; then
  echo "Adding subscription_id_management as variable to $FILE_VARIABLES."
  cat <<EOF >> $DIRECTORY_BRIDGEHEAD/$FILE_VARIABLES

variable "subscription_id_management" {
  description = "The Azure subscription ID of enterprise scale management."
  type        = string
  sensitive   = true
  default     = ""
}
EOF
fi

if [ -n "$IDENTITY_SUBSCRIPTION_ID" ]; then
  echo "Adding subscription_id_identity as variable to $FILE_VARIABLES."
  cat <<EOF >> $DIRECTORY_BRIDGEHEAD/$FILE_VARIABLES

variable "subscription_id_identity" {
  description = "The Azure subscription ID of enterprise scale identity."
  type        = string
  sensitive   = true
  default     = ""
}
EOF
fi

###########################################
# tfvars File
###########################################

echo "Creating $FILE_TFVARS."
cat <<EOF > $DIRECTORY_BRIDGEHEAD/$FILE_TFVARS
basename                 = "$BASENAME"
location                 = "$LOCATION"
account_tier             = "$ACCOUNT_TIER"
account_replication_type = "$ACCOUNT_REPLICATION_TYPE"
EOF

###########################################
# Bridgehead Main File
###########################################

echo "Creating $FILE_MAIN."
cat <<EOF > $DIRECTORY_BRIDGEHEAD/$FILE_MAIN
###############################################################
# Local Variables
###############################################################

locals {
  tags = {
    environment = "terraform bridgehead"
    managedby   = "terraform"
  }
}

##################################
# Resource Group for BRIDGEHEAD
##################################

# https://registry.terraform.io/providers/aztfmod/azurecaf/latest
resource "azurecaf_name" "rg" {
  name          = var.basename
  resource_type = "azurerm_resource_group"
  random_length = 0
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group
resource "azurerm_resource_group" "this" {
  name     = azurecaf_name.rg.result
  location = var.location
  tags     = local.tags
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
resource "azurerm_storage_account" "this" {
  name                     = azurecaf_name.stracc.result
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  tags                     = local.tags
}

##################################
# Blob Container for Bridgehead and Terraform CAF Enterprise Scale (tfcafes) state file
##################################

# https://registry.terraform.io/providers/aztfmod/azurecaf/latest
resource "azurecaf_name" "blob" {
  name          = var.basename
  resource_type = "azurerm_storage_blob"
  random_length = 0
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container
resource "azurerm_storage_container" "this" {
  name                  = azurecaf_name.blob.result
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"

  lifecycle { prevent_destroy = true }
}

##################################
# Key Vault for storing secrets
##################################

# https://registry.terraform.io/providers/aztfmod/azurecaf/latest
resource "azurecaf_name" "kv" {
  name          = var.basename
  resource_type = "azurerm_key_vault"
  random_length = 5
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault
resource "azurerm_key_vault" "this" {
  name                      = azurecaf_name.kv.result
  location                  = azurerm_resource_group.this.location
  resource_group_name       = azurerm_resource_group.this.name
  sku_name                  = var.keyvault_sku_name
  tenant_id                 = var.tenant_id
  enable_rbac_authorization = true
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config
data "azurerm_client_config" "this" {
}

# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
resource "azurerm_role_assignment" "automationuser" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.this.object_id
}
EOF

###########################################
# Bridgehead Key Vault Secrets File
###########################################

echo "Creating $FILE_SECRETS."
cat <<EOF > $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS
##################################
# Secrets
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret
##################################

resource "azurerm_key_vault_secret" "tenantid" {
  name         = "tenant-id"
  value        = var.tenant_id
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.automationuser]
}
EOF


if [ -n "$CONNECTIVITY_SUBSCRIPTION_ID" ]; then
  echo "Adding subscription_id_connectivity as secret to $FILE_SECRETS."
  cat <<EOF >> $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS

resource "azurerm_key_vault_secret" "connectivitysubscription" {
  name         = "subscription-id-connectivity"
  value        = var.subscription_id_connectivity
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.automationuser]
}
EOF
fi

if [ -n "$MANAGEMENT_SUBSCRIPTION_ID" ]; then
  echo "Adding subscription_id_management as secret to $FILE_SECRETS."
  cat <<EOF >> $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS

resource "azurerm_key_vault_secret" "managementsubscription" {
  name         = "subscription-id-management"
  value        = var.subscription_id_management
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.automationuser]
}
EOF
fi

if [ -n "$IDENTITY_SUBSCRIPTION_ID" ]; then
  echo "Adding subscription_id_identity as secret to $FILE_SECRETS."
  cat <<EOF >> $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS

resource "azurerm_key_vault_secret" "identitysubscription" {
  name         = "subscription-id-identity"
  value        = var.subscription_id_identity 
  key_vault_id = azurerm_key_vault.this.id
  depends_on   = [azurerm_role_assignment.automationuser]
}
EOF
fi

echo "Adding additional subscription IDs as secrets to $FILE_SECRETS."

for group in $(jq -r '.settings.enterprisescale.custom_management_groups | keys[]' "$JSON_FILE"); do
  id=$(jq -r ".settings.enterprisescale.custom_management_groups.$group.id" "$JSON_FILE")
  subscription_ids=($(jq -c ".settings.enterprisescale.custom_management_groups.$group.subscription_ids[]" "$JSON_FILE"))

  # Check if id is not null
  if [[ "$id" != null ]]; then
    index=0
    for subscription_id in "${subscription_ids[@]}"; do
      ADDITIONAL_SUBSCRIPTIONS+="\n"
      ADDITIONAL_SUBSCRIPTIONS+="resource \"azurerm_key_vault_secret\" \"subscription$group$index\" {\n"
      ADDITIONAL_SUBSCRIPTIONS+="  name         = \"subscription-id-$group-$index\"\n"
      ADDITIONAL_SUBSCRIPTIONS+="  value        = var.subscription_id_${group}_${index}\n"
      ADDITIONAL_SUBSCRIPTIONS+="  key_vault_id = azurerm_key_vault.this.id\n"
      ADDITIONAL_SUBSCRIPTIONS+="  depends_on   = [azurerm_role_assignment.automationuser]\n"
      ADDITIONAL_SUBSCRIPTIONS+="}\n"
      index=$(($index+1))
    done
  fi
done

echo -e "$ADDITIONAL_SUBSCRIPTIONS" >> $DIRECTORY_BRIDGEHEAD/$FILE_SECRETS
ADDITIONAL_SUBSCRIPTIONS=""

###########################################
# Additional subscription IDs as variables in file $FILE_VARIABLES
###########################################

echo "Adding additional subscription IDs as secrets to $FILE_VARIABLES."

for group in $(jq -r '.settings.enterprisescale.custom_management_groups | keys[]' "$JSON_FILE"); do
  id=$(jq -r ".settings.enterprisescale.custom_management_groups.$group.id" "$JSON_FILE")
  #subscription_ids=($(jq -c ".settings.enterprisescale.custom_management_groups.$group.subscription_ids[]" "$JSON_FILE"))
  subscription_ids=($(jq -r -c ".settings.enterprisescale.custom_management_groups.$group.subscription_ids[]" "$JSON_FILE"))

  if [[ "$id" != null ]]; then
    index=0
    for subscription_id in "${subscription_ids[@]}"; do
      ADDITIONAL_SUBSCRIPTIONS+="\n"
      ADDITIONAL_SUBSCRIPTIONS+="variable \"subscription_id_${group}_${index}\" {\n"
      ADDITIONAL_SUBSCRIPTIONS+="  description = \"The Azure subscription connected to management group ${group}.\"\n"
      ADDITIONAL_SUBSCRIPTIONS+="  type        = string\n"
      ADDITIONAL_SUBSCRIPTIONS+="  sensitive   = true\n"
      ADDITIONAL_SUBSCRIPTIONS+="  default     = \"\"\n"
      ADDITIONAL_SUBSCRIPTIONS+="}\n"

      varname="TF_VAR_subscription_id_${group}_${index}"
      export $varname=$subscription_id

      index=$(($index+1))
    done
  fi
done

echo -e "$ADDITIONAL_SUBSCRIPTIONS" >> $DIRECTORY_BRIDGEHEAD/$FILE_VARIABLES
ADDITIONAL_SUBSCRIPTIONS=""

#########################################
# Export Bash Environment Variables
###########################################

export ARM_CLIENT_ID=$ARM_CLIENT_ID
export ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET
export ARM_TENANT_ID=$ARM_TENANT_ID
export ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID

export TF_VAR_tenant_id=$ARM_TENANT_ID

if [ -n "$CONNECTIVITY_SUBSCRIPTION_ID" ]; then
  export TF_VAR_subscription_id_connectivity=$CONNECTIVITY_SUBSCRIPTION_ID
fi

if [ -n "$MANAGEMENT_SUBSCRIPTION_ID" ]; then
  export TF_VAR_subscription_id_management=$MANAGEMENT_SUBSCRIPTION_ID
fi

if [ -n "$IDENTITY_SUBSCRIPTION_ID" ]; then
  export TF_VAR_subscription_id_identity=$IDENTITY_SUBSCRIPTION_ID
fi


###########################################
# Terraform Init
###########################################

print_empty_lines 1
echo "Executing terraform init."
if terraform -chdir=$DIRECTORY_BRIDGEHEAD init
then
  print_empty_lines 1
  echo -e "\e[1;32m"Terraform init executed successfully."\e[0m"
else
  print_empty_lines 1
  echo -e "\e[1;31m"Terraform init failed."\e[0m"
  exit 1
fi

###########################################
# Terraform Validate
###########################################

print_empty_lines 1
echo "Executing terraform validate."
if terraform -chdir=$DIRECTORY_BRIDGEHEAD validate
then
  print_empty_lines 1
  echo -e "\e[1;32m"Terraform validate executed successfully."\e[0m"
else
  print_empty_lines 1
  echo -e "\e[1;31m"Terraform validate failed."\e[0m"
  exit 1
fi

###########################################
# Terraform Apply
###########################################

print_empty_lines 1
echo "Executing terraform apply."
print_empty_lines 1
if terraform -chdir=$DIRECTORY_BRIDGEHEAD apply -auto-approve --var-file=$FILE_TFVARS
then
  print_empty_lines 1
  echo -e "\e[1;32m"Terraform apply executed successfully."\e[0m"
else
  print_empty_lines 1
  echo -e "\e[1;31m"Terraform apply failed."\e[0m"
  exit 1
fi

####################################
# Configure Azure backend
####################################

RESOURCE_GROUP_NAME=$(terraform -chdir=$DIRECTORY_BRIDGEHEAD output resource_group_name)
STORAGE_ACCOUNT_NAME=$(terraform -chdir=$DIRECTORY_BRIDGEHEAD output storage_account_name)
CONTAINER_NAME=$(terraform -chdir=$DIRECTORY_BRIDGEHEAD output container_name)

cat <<EOF > $DIRECTORY_BRIDGEHEAD/$FILE_BACKEND
terraform {
  backend "azurerm" {
    resource_group_name = $RESOURCE_GROUP_NAME
    storage_account_name = $STORAGE_ACCOUNT_NAME
    container_name = $CONTAINER_NAME
    key = "$BASENAME.tfstate"
  }
}
EOF

if terraform -chdir=$DIRECTORY_BRIDGEHEAD init <<EOF
yes
EOF
then
  print_empty_lines 1
  echo -e "\e[1;32m"Bridgehead successfully installed."\e[0m"
else
  echo -e "\e[1;31m"Initializing Azure Backend failed."\e[0m"
  exit 1
fi

####################################
# Some post steps
####################################

print_empty_lines 2
echo "Post Steps: Formatting all Terraform files."
terraform -chdir=$DIRECTORY_BRIDGEHEAD fmt >/dev/null 2>&1

echo "Post Steps: Removing local state file."
print_empty_lines 2
rm -f $DIRECTORY_BRIDGEHEAD/terraform.tfstate* >/dev/null 2>&1

echo "Post Steps: Removing $JSON_FILE."
rm $JSON_FILE > /dev/null 2>&1