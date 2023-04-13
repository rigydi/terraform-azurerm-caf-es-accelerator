#!/bin/bash

TESTFILE="test.sh"
PATH_TO_LAUNCHPAD="../../launchpad"
LAUNCHPAD_SETUP="launchpad.sh"

function cleanup {
  # remove all files except for the test file
  files=$(find . -maxdepth 1 -type f -not -name $TESTFILE)
  if [ -n "$files" ]; then
    echo "$files" | xargs rm
    rm -rf .terraform > /dev/null 2>&1
  fi
}

function handle_interrupt () {
    print_empty_lines 2
    echo "Cleaning up files."
    cleanup
    echo "Finished. Exiting ..."    
    exit 1
}

function handle_error () {
    print_empty_lines 2
    echo "An error occurred."
    cleanup
    echo "Exiting ..."    
    exit 1
}

trap 'handle_interrupt' INT
trap 'handle_error' ERR

# Some clean up
cleanup

# copy required files
cp -av $PATH_TO_LAUNCHPAD/{*.tf,*.sh} .

export TERM=xterm-256color


# run test
echo "Running terraform apply to create all resources."
# $1 ARM_CLIENT_ID, $2 ARM_CLIENT_SECRET, $3 ARM_SUBSCRIPTION_ID, $4 ARM_TENANT_ID
./$LAUNCHPAD_SETUP <<EOF
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
  echo "Test passed."

  echo "Removing lifecycle restriction from resources."
  sed -i '/lifecycle/d' main.tf

  echo "Pull state to local file."
  terraform state pull > terraform.tfstate

  echo "Remove backend definition."
  rm backend.tf

  echo "Initialize Terraform."
  terraform init -migrate-state

  echo "Run terraform destroy."
  terraform destroy -auto-approve

  echo "Cleaning up files."
  cleanup
  exit 0
else
  echo "Test failed. Cleaning up files."
  cleanup
  exit 1
fi