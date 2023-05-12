#!/usr/bin/env bash

export TERM=xterm-256color

############################
# Check Inputs
############################
TEMP=$(getopt -o '' --long client_id:,client_secret:,tenant_id:,subscription_id:,environment:,action: -- "$@")
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
    --action)
      ACTION="$2"
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
  echo "Error running shell script. Following input is required: --client_id <Service Principal Client ID> --client_secret <Service Principal Client Secret> --tenant_id <AAD Tenant ID --subscription_id <Azure Subscription ID> --environment <e.g. dev, stage, prod> --action <deploy|destroy|cycle>" >&2
  exit 1
fi

if [[ "${ACTION}" != "deploy" && "${ACTION}" != "destroy" && "${ACTION}" != "cycle" ]]; then
  echo "Error running script. Use --action to specify one of: deploy, destroy, cycle. Cycle means deploy&destroy" >&2
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

FILE_SETUP_BRIDGEHEAD="01_setup_bridgehead.sh"
FILE_SETUP_ES="02_bootstrap_enterprise_scale.sh"
FILE_TEST="test.sh"
FILE_SETTINGS_YAML="bootstrap.yaml"
FILE_TFVARS="terraform-$ENVIRONMENT.tfvars"

DIRECTORY_ROOT=$(find / -type f -name $FILE_SETUP_ES -printf "%h\n" 2>/dev/null | awk '{ print length, $0 }' | sort -n | cut -d" " -f2- | head -n 1)
DIRECTORY_TEST=$(find / -type f -name $FILE_TEST -printf "%h\n" 2>/dev/null | awk '{ print length, $0 }' | sort -n | cut -d" " -f2- | head -n 1)
DIRECTORY_TEST_TARGET="$DIRECTORY_TEST/tmp_testrun"
DIRECTORY_TEST_TARGET_BRIDGEHEAD="$DIRECTORY_TEST_TARGET/01_bridgehead"
DIRECTORY_TEST_TARGET_ENTERPRISE_SCALE="$DIRECTORY_TEST_TARGET/02_enterprisescale"

export ARM_CLIENT_ID=$ARM_CLIENT_ID
export ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET
export ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID
export ARM_TENANT_ID=$ARM_TENANT_ID

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
    print_empty_lines 1
    echo "Preparations: Removing old test run directory."
    rm -rf $DIRECTORY_TEST_TARGET
  fi
}

############################
# Prepare Testrun folder and Files
############################

if [[ "$ACTION" == "deploy" || "$ACTION" == "cycle" ]]
then
  cleanup
  echo "Preparations: Creating directory $DIRECTORY_TEST_TARGET."
  mkdir -p $DIRECTORY_TEST_TARGET

  echo "Preparations: Copying $FILE_SETTINGS_YAML to directory $DIRECTORY_TEST_TARGET."
  cp -a $DIRECTORY_TEST/$FILE_SETTINGS_YAML $DIRECTORY_TEST_TARGET
fi

############################
# Bridgehead - Installation
############################

if [[ "$ACTION" == "deploy" || "$ACTION" == "cycle" ]]
then
  print_empty_lines 1
  echo "Bridgehead: Copying $FILE_SETUP_BRIDGEHEAD from $DIRECTORY_ROOT to $DIRECTORY_TEST_TARGET."
  cp -a $DIRECTORY_ROOT/$FILE_SETUP_BRIDGEHEAD $DIRECTORY_TEST_TARGET

  echo "Bridgehead: Starting installation."
  cd $DIRECTORY_TEST_TARGET
  if ./$FILE_SETUP_BRIDGEHEAD --client_id $ARM_CLIENT_ID --client_secret $ARM_CLIENT_SECRET --tenant_id $ARM_TENANT_ID --subscription_id $ARM_SUBSCRIPTION_ID --environment $ENVIRONMENT
  then
    echo "Bridgehead: Azure resources successfully deployed."
  else
    echo "Bridgehead: Azure resource installation failed."
    exit 1
  fi
fi

############################
# TF-CAF-ES - Installation
############################

if [[ "$ACTION" == "deploy" || "$ACTION" == "cycle" ]]
then
  print_empty_lines 1
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
  print_empty_lines 1
  if terraform -chdir=$DIRECTORY_TEST_TARGET_ENTERPRISE_SCALE init
  then
    print_empty_lines 1
    echo "TF-CAF-ES: Initializing Terraform was successful."
  else
    print_empty_lines 1
    echo "TF-CAF-ES: Initializing Terraform failed."
    exit 1
  fi

  echo -n "TF-CAF-ES: Creating Azure resouces."
  print_empty_lines 1
  if terraform -chdir=$DIRECTORY_TEST_TARGET_ENTERPRISE_SCALE apply -auto-approve
  then
    print_empty_lines 1
    echo "TF-CAF-ES: Terraform apply executed successfully."
  else
    print_empty_lines 1
    echo "TF-CAF-ES: Terraform apply failed."
    exit 1
  fi
fi

############################
# TF-CAF-ES Destruction
############################

if [[ "$ACTION" == "destroy" || "$ACTION" == "cycle" ]]
then
  print_empty_lines 1
  echo -n "TF-CAF-ES: Destroying Terraform resources."
  print_empty_lines 1
  if terraform -chdir=$DIRECTORY_TEST_TARGET_ENTERPRISE_SCALE destroy -auto-approve
  then
    print_empty_lines 1
    echo "TF-CAF-ES: Terraform destroy executed successfully."
  else
    print_empty_lines 1
    echo "TF-CAF-ES: Terraform destroy failed."
    exit
  fi
fi

############################
# Bridgehead Destruction
############################

if [[ "$ACTION" == "destroy" || "$ACTION" == "cycle" ]]
then
  # echo "Bridgehead: Removing lifecycle restriction from resources."
  # sed -i '/lifecycle/d' $DIRECTORY_TEST_TARGET_BRIDGEHEAD/main.tf

  # echo "Bridgehead: Pull state to local file."
  # terraform -chdir=$DIRECTORY_TEST_TARGET_BRIDGEHEAD state pull > $DIRECTORY_TEST_TARGET_BRIDGEHEAD/terraform.tfstate

  # echo "Bridgehead: Remove backend definition."
  # rm $DIRECTORY_TEST_TARGET_BRIDGEHEAD/backend.tf

  # echo "Bridgehead: Migrate state before destroying resources."
  # print_empty_lines 1
  # if terraform -chdir=$DIRECTORY_TEST_TARGET_BRIDGEHEAD init -migrate-state
  # then
  #   print_empty_lines 1
  #   echo "Bridgehead: Successfully migrated Terraform state."
  # else
  #   print_empty_lines 1
  #   echo "Bridgehead: Terraform state migration failed."
  #   exit 1
  # fi

  # echo "Bridgehead: Initializing Terraform before destroying resources."
  # print_empty_lines 1
  # if terraform -chdir=$DIRECTORY_TEST_TARGET_BRIDGEHEAD init
  # then
  #   print_empty_lines 1
  #   echo "Bridgehead: Successfully initialized Terraform."
  # else
  #   print_empty_lines 1
  #   echo "Bridgehead: Terraform initializiation failed."
  #   exit 1
  # fi

  # echo "Bridgehead: Run terraform destroy."
  # print_empty_lines 1
  # if terraform -chdir=$DIRECTORY_TEST_TARGET_BRIDGEHEAD destroy -auto-approve --var-file=$FILE_TFVARS
  # then
  #   print_empty_lines 1
  #   echo "Bridgehead: Resources successfully destroyed."
  #   print_empty_lines 3
  #   echo "Testrun was successfull."
  #   print_empty_lines 1
  # else
  #   print_empty_lines 1
  #   echo "Bridgehead: Resource destruction failed."
  #   exit 1
  # fi

  RESOURCE_GROUP_NAME=$(terraform -chdir=$DIRECTORY_TEST_TARGET_BRIDGEHEAD output resource_group_name)
  RESOURCE_GROUP_NAME=$(awk '{gsub(/"/,"",$0); print $0}' <<<"$RESOURCE_GROUP_NAME")
  az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID >/dev/null 2>&1

  echo "Bridgehead: Destroying all resources."
  if az group delete --yes -n $RESOURCE_GROUP_NAME >/dev/null 2>&1
  then
    echo "Bridgehead: Resources successfully destroyed."
    print_empty_lines 3
    echo "Testrun was successfull."
    print_empty_lines 1
  else
    print_empty_lines 1
    echo "Bridgehead: Resource destruction failed."
    exit 1
  fi 
fi