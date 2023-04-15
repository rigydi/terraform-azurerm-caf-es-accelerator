#!/usr/bin/env bash

FILE_TEST="test.sh"
FILE_LAUNCHPAD_SETUP="setup.sh"
FILE_BOOTSTRAP_SETUP="bootstrap.sh"
FILE_BOOTSTRAP_YAML="bootstrap.yaml"

DIRECTORY_ROOT=$(find / -type f -name $FILE_BOOTSTRAP_SETUP -printf "%h\n" 2>/dev/null | awk '{ print length, $0 }' | sort -n | cut -d" " -f2- | head -n 1)
DIRECTORY_TEST_SOURCE=$(find / -type f -name $FILE_TEST -printf "%h\n" 2>/dev/null | awk '{ print length, $0 }' | sort -n | cut -d" " -f2- | head -n 1)
DIRECTORY_LAUNCHPAD_SOURCE=$(find / -type f -name $FILE_LAUNCHPAD_SETUP -printf "%h\n" 2>/dev/null | awk '{ print length, $0 }' | sort -n | cut -d" " -f2- | head -n 1)

DIRECTORY_TEST_TARGET="$DIRECTORY_TEST_SOURCE/tmp_testrun"
DIRECTORY_LAUNCHPAD_TARGET="$DIRECTORY_TEST_TARGET/launchpad"

function cleanup {
  if [ -d "$DIRECTORY_TEST_TARGET" ]; then
    echo "Removed old test run directory."
    rm -rf $DIRECTORY_TEST_TARGET
  fi
}

cleanup

function print_empty_lines() {
  for (( i=1; i<=$1; i++ ))
  do
    echo ""
  done
}

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

cleanup

export TERM=xterm-256color

############################
# Launchpad Installation
############################

echo "Launchpad: Create launchpad directory."
mkdir -p $DIRECTORY_LAUNCHPAD_TARGET

echo "Launchpad: Copy launchpad files to $DIRECTORY_LAUNCHPAD_TARGET."
cp -a $DIRECTORY_LAUNCHPAD_SOURCE/{*.tf,*.sh} $DIRECTORY_LAUNCHPAD_TARGET

echo "Launchpad: Running terraform apply to create all resources."
# $1 ARM_CLIENT_ID, $2 ARM_CLIENT_SECRET, $3 ARM_SUBSCRIPTION_ID, $4 ARM_TENANT_ID
cd $DIRECTORY_LAUNCHPAD_TARGET
./$FILE_LAUNCHPAD_SETUP <<EOF
yes
$1
$2
yes
$3
$4
westeurope
yes
yes
yes
yes
EOF

RETURN_CODE=$?

if [ $RETURN_CODE -eq 0 ]; then
  echo "Launchpad: Azure resources successfully deployed."
else
  echo "Launchpad: Azure resource installation failed."
  exit 1
fi


############################
# TF-CAF-ES Installation
############################

echo "TF-CAF-ES: Creating directories."
cp -a $DIRECTORY_ROOT/$FILE_BOOTSTRAP_SETUP $DIRECTORY_TEST_TARGET/

echo "TF-CAF-ES: Copying FILE_BOOTSTRAP_YAML to $DIRECTORY_TEST_TARGET."
cp -a $DIRECTORY_TEST_SOURCE/$FILE_BOOTSTRAP_YAML $DIRECTORY_TEST_TARGET/

echo "TF-CAF-ES: Creating Terraform configuration files."
cd $DIRECTORY_TEST_TARGET
./$FILE_BOOTSTRAP_SETUP

echo "TF-CAF-ES: Declaring environment variables for Azure authentication."
export ARM_CLIENT_ID="$1"
export ARM_CLIENT_SECRET="$2"
export ARM_SUBSCRIPTION_ID="$3"
export ARM_TENANT_ID="$4"

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
sed -i '/lifecycle/d' $DIRECTORY_LAUNCHPAD_TARGET/main.tf

echo "Launchpad: Pull state to local file."
terraform -chdir=$DIRECTORY_LAUNCHPAD_TARGET state pull > $DIRECTORY_LAUNCHPAD_TARGET/terraform.tfstate

echo "Launchpad: Remove backend definition."
rm $DIRECTORY_LAUNCHPAD_TARGET/backend.tf

echo "Launchpad: Initialize Terraform before destroying."
if terraform -chdir=$DIRECTORY_LAUNCHPAD_TARGET/ init -migrate-state
then
  print_empty_lines 1
  echo "Launchpad: Successfully initialized Terraform."
else
  print_empty_lines 1
  echo "Launchpad: Terraform initializiation failed."
  exit 1
fi

echo "Launchpad: Run terraform destroy."
if terraform -chdir=$DIRECTORY_LAUNCHPAD_TARGET destroy -auto-approve
then
  print_empty_lines 1
  echo "Launchpad: Resources successfully destroyed."
  print_empty_lines 3
  echo "Test was successfull."
else
  print_empty_lines 1
  echo "Launchpad: Resource destruction failed."
  exit 1
fi
