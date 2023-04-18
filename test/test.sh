#!/usr/bin/env bash

export TERM=xterm-256color

############################
# Check Inputs
############################

while getopts 'i:s:' flag; do
  case "${flag}" in
    i) CLIENT_ID="${OPTARG}" ;;
    s) CLIENT_SECRET="${OPTARG}" ;;
    *) echo "Invalid option: -$OPTARG" >&2
       exit 1 ;;
  esac
done

if [[ -z "${CLIENT_ID}" || -z "${CLIENT_SECRET}" ]]; then
  echo "Error: Missing option flag(s). Please run the script with both options: -i <Service Principal Client ID> -s <Service Principal Client Secret>" >&2
  exit 1
fi

############################
# Signal Handling
############################

function handle_interrupt () {
    print_empty_lines 2
    echo "Process interrupted. Exiting ..."    
    exit 1
}

function handle_error () {
    print_empty_lines 2
    echo "An error occurred. Exiting ..."
    exit 1
}

trap 'handle_interrupt' INT
trap 'handle_error' ERR

############################
# Variables
############################

FILE_SETUP_LAUNCHPAD="setup-launchpad.sh"
FILE_SETUP_ES="bootstrap-enterprise-scale.sh"
FILE_TEST="test.sh"
FILE_SETTINGS_YAML="bootstrap.yaml"

DIRECTORY_ROOT=$(find / -type f -name $FILE_SETUP_ES -printf "%h\n" 2>/dev/null | awk '{ print length, $0 }' | sort -n | cut -d" " -f2- | head -n 1)
DIRECTORY_TEST=$(find / -type f -name $FILE_TEST -printf "%h\n" 2>/dev/null | awk '{ print length, $0 }' | sort -n | cut -d" " -f2- | head -n 1)
DIRECTORY_TEST_TARGET="$DIRECTORY_TEST/tmp_testrun"
DIRECTORY_TEST_TARGET_LAUNCHPAD="$DIRECTORY_TEST_TARGET/launchpad"

TENANT_ID=$(yq '.settings.launchpad.tenant_id' $FILE_SETTINGS_YAML)
SUBSCRIPTION_ID=$(yq '.settings.launchpad.subscription_id' $FILE_SETTINGS_YAML)

export ARM_CLIENT_ID=$CLIENT_ID
export ARM_CLIENT_SECRET=$CLIENT_SECRET
export ARM_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
export ARM_TENANT_ID=$TENANT_ID

############################
# Some Functions
############################

function print_empty_lines() {
  for (( i=1; i<=$1; i++ ))
  do
    echo ""
  done
}

function cleanup {
  if [ -d "$DIRECTORY_TEST_TARGET" ]; then
    echo "Removed old test run directory."
    rm -rf $DIRECTORY_TEST_TARGET
  fi
}

############################
# Prepare Testrun folder and Files
############################

print_empty_lines 1
echo "Creating directory $DIRECTORY_TEST_TARGET."
mkdir -p $DIRECTORY_TEST_TARGET

print_empty_lines 1
echo "Copying $FILE_SETTINGS_YAML to directory $DIRECTORY_TEST_TARGET."
cp -a $DIRECTORY_TEST/$FILE_SETTINGS_YAML $DIRECTORY_TEST_TARGET

############################
# Launchpad - Installation
############################

print_empty_lines 1
echo "Launchpad: Copying $FILE_SETUP_LAUNCHPAD to $DIRECTORY_TEST_TARGET."
cp -a $DIRECTORY_ROOT/$FILE_SETUP_LAUNCHPAD $DIRECTORY_TEST_TARGET

print_empty_lines 1
echo "Launchpad: Starting installation."
cd $DIRECTORY_TEST_TARGET
if ./$FILE_SETUP_LAUNCHPAD -i $CLIENT_ID -s $CLIENT_SECRET
then
  echo "Launchpad: Azure resources successfully deployed."
else
  echo "Launchpad: Azure resource installation failed."
  exit 1
fi

############################
# TF-CAF-ES - Installation
############################

echo "TF-CAF-ES: Copying $FILE_SETUP_ES to $DIRECTORY_TEST_TARGET."
cp -a $DIRECTORY_ROOT/$FILE_SETUP_ES $DIRECTORY_TEST_TARGET/

echo "TF-CAF-ES: Copying FILE_SETTINGS_YAML to $DIRECTORY_TEST_TARGET."
cp -a $DIRECTORY_TEST/$FILE_SETTINGS_YAML $DIRECTORY_TEST_TARGET/

echo "TF-CAF-ES: Creating Terraform configuration files."
cd $DIRECTORY_TEST_TARGET

if ./$FILE_SETUP_ES
then
  echo "TF-CAF-ES: Configuration files successfully created."
else
  echo "TF-CAF-ES: Error while creating configuration files."
  exit 1
fi

echo -n "TF-CAF-ES: Initializing Terraform."
if terraform -chdir=$DIRECTORY_TEST_TARGET init
then
  print_empty_lines 1
  echo "TF-CAF-ES: Initializing Terraform was successful."
else
  print_empty_lines 1
  echo "TF-CAF-ES: Initializing Terraform failed."
  exit 1
fi

echo -n "TF-CAF-ES: Creating Azure resouces."
if terraform -chdir=$DIRECTORY_TEST_TARGET apply -auto-approve
then
  print_empty_lines 1
  echo "TF-CAF-ES: Terraform apply executed successfully."
else
  print_empty_lines 1
  echo "TF-CAF-ES: Terraform apply failed."
  exit 1
fi

############################
# TF-CAF-ES Destruction
############################

echo -n "TF-CAF-ES: Destroying Terraform resources."
if terraform -chdir=$DIRECTORY_TEST_TARGET destroy -auto-approve
then
  print_empty_lines 1
  echo "TF-CAF-ES: Terraform destroy executed successfully."
else
  print_empty_lines 1
  echo "TF-CAF-ES: Terraform destroy failed."
  exit
fi

############################
# Launchpad Destruction
############################
  
echo "Launchpad: Removing lifecycle restriction from resources."
sed -i '/lifecycle/d' $DIRECTORY_TEST_TARGET_LAUNCHPAD/main.tf

echo "Launchpad: Pull state to local file."
terraform -chdir=$DIRECTORY_TEST_TARGET_LAUNCHPAD state pull > $DIRECTORY_TEST_TARGET_LAUNCHPAD/terraform.tfstate

echo "Launchpad: Remove backend definition."
rm $DIRECTORY_TEST_TARGET_LAUNCHPAD/backend.tf

echo "Launchpad: Initialize Terraform before destroying."
if terraform -chdir=$DIRECTORY_TEST_TARGET_LAUNCHPAD/ init -migrate-state
then
  print_empty_lines 1
  echo "Launchpad: Successfully initialized Terraform."
else
  print_empty_lines 1
  echo "Launchpad: Terraform initializiation failed."
  exit 1
fi

echo "Launchpad: Run terraform destroy."
if terraform -chdir=$DIRECTORY_TEST_TARGET_LAUNCHPAD destroy -auto-approve
then
  print_empty_lines 1
  echo "Launchpad: Resources successfully destroyed."
  print_empty_lines 3
  echo "Testrun was successfull."
else
  print_empty_lines 1
  echo "Launchpad: Resource destruction failed."
  exit 1
fi