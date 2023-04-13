#!/bin/bash

set -e

TESTFILE=test.sh

function CLEANUP {
  # remove all files except for the test file
  files=$(find . -maxdepth 1 -type f -not -name $TESTFILE)
  if [ -n "$files" ]; then
    echo "$files" | xargs rm
    rm -rf .terraform > /dev/null 2>&1
  fi
}

# Some clean up
CLEANUP

# copy required files
cp -av ../../launchpad/{*.tf,*.sh} .

export TERM=xterm-256color


# run test
echo "Running terraform apply to create all resources."
# $1 ARM_CLIENT_ID, $2 ARM_CLIENT_SECRET, $3 ARM_SUBSCRIPTION_ID, $4 ARM_TENANT_ID
source launchpad.sh <<EOF
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
  CLEANUP
  exit 0
else
  echo "Test failed. Cleaning up files."
  CLEANUP
  exit 1
fi