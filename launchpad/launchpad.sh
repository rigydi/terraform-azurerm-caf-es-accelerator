#!/usr/bin/bash

clear

echo -e "\e[1;32m====================================================================\e[0m"
echo -e "\e[1;32m|                        Welcome                                   |\e[0m"
echo -e "\e[1;32m|                                                                  |\e[0m"
echo -e "\e[1;32m|  This script will help you getting started with Terraform on     |\e[0m"
echo -e "\e[1;32m|  Azure. It will deploy the launchpad resources listed in main.tf |\e[0m"
echo -e "\e[1;32m|  and configure the Azure backend for state file management.      |\e[0m"
echo -e "\e[1;32m====================================================================\e[0m"

####################################
# Variables
####################################

TFPLANFILE="plan.tfplan"
TFBACKENDFILE="backend.tf"

####################################
# functions
####################################

function print_empty_lines() {
  for (( i=1; i<=$1; i++ ))
  do
    echo ""
  done
}

exit_function () {
    trap SIGINT
    print_empty_lines 2
    echo -n "Cleaning up files."
    rm -rvf .terraform* backend.tf terraform.tfstate* terraform.tfvars *.tfplan >/dev/null 2>&1
    echo -n "Finished. Exiting ..."    
    return 1
}

trap "exit_function" INT

####################################
# Introduction
####################################

rm -rvf .terraform* backend.tf terraform.tfstate* terraform.tfvars *.tfplan >/dev/null 2>&1

print_empty_lines 2
echo -n "Before deploying Azure resources, you need to create a Service Principal for authenticating to Azure. All deployments will be done with this user. If not already done, please create this user now and assign the <Owner> role with scope <Tenant Root Management Group>. Before you continue make sure you have access to the Client ID and Client Secret. Are you ready? (yes/no): "
read answer

if [ "$answer" == "yes" ]; then
  print_empty_lines 1
  echo -n "Alright, let us continue."
else
  print_empty_lines 1
  echo -n "Good bye."
  return 1
fi

####################################
# Service Principal
####################################

print_empty_lines 2

echo -n "Enter Service Principal Client ID: "
read ARM_CLIENT_ID
export ARM_CLIENT_ID=$ARM_CLIENT_ID

echo -n "Enter Service Principal Client Secret. (The input is not shown in the command prompt): "
read -s ARM_CLIENT_SECRET
export ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET


####################################
# terraform.tfvars
####################################

print_empty_lines 2
echo -n "The script will now read the content of the variables.tf file and asks you for input of those variables which do not have a default value assigned. Are you ready? (yes/no): "  
read answer

if [ "$answer" == "yes" ]; then
  print_empty_lines 1
  echo -n "Alright, let us continue."
else
  print_empty_lines 1
  echo -n "Good bye."
  return 1
fi

# Loop through each variable in var_names array
print_empty_lines 2
for var_name in $(awk '/variable/ {print $2}' variables.tf | tr -d '"')
do
  # Find default value of variable
  var_default=$(awk -v var="$var_name" '/variable/ {p=0} $0~var {p=1} p && /default/ {print $3}' variables.tf | tr -d '"')

  # Find description of variable
  var_description=$(awk -v var="$var_name" '/variable/ {p=0} $0~var {p=1} p && /description/ {for (i=2; i<=NF; i++) printf("%s ", $i); printf("\n")}' variables.tf | tr -d '"')

  # Ask user for input if no default value exists
  if [[ $var_default == "" ]]; then
    read -p "Please enter the value for variable $var_name ($var_description): " var_value
    export TF_VAR_$var_name=$var_value
    # Populate the terraform.tfvars file with the user provided variable values
    echo $var_name=\"$var_value\" >> terraform.tfvars
  else
    export TF_VAR_$var_name=$var_default
  fi
done


####################################
# Terraform init
####################################

print_empty_lines 1
echo -n "Now Terraform needs to be initialized. Would you like to do continue? (yes/no): "
read answer

if [ "$answer" == "yes" ]; then
  # some clean up tasks
  if [ -d ".terraform" ]; then
    rm -rf .terraform >/dev/null 2>&1
  fi
  if [ -f "$TFBACKENDFILE" ]; then
    rm ./$TFBACKENDFILE
  fi
  # Execute terraform init and check if it was executed successfully
  if terraform init
  then
    print_empty_lines 1
    echo -e "\e[1;32m"Terraform init executed successfully."\e[0m"
  else
    print_empty_lines 1
    echo -e "\e[1;31m"Terraform init failed."\e[0m"
    return 1
  fi
else
  print_empty_lines 1
  echo -n "Good bye."
  return 1
fi 


####################################
# Terraform plan
####################################

print_empty_lines 2
echo -n "We will now check if Terraform is able to plan the resource deployment. Would you like to continue? (yes/no): "
read answer
if [ "$answer" == "yes" ]; then
  # clean up old plan files first
  if [ -f "$TFPLANFILE" ]; then
    rm $TFPLANFILE
  fi
  # Execute terraform plan and check if it was executed successfully
  terraform plan -out $TFPLANFILE

  if [[ -f $TFPLANFILE ]]
  then
    print_empty_lines 1
    echo -e "\e[1;32m"Terraform plan executed successfully."\e[0m"
  else
    print_empty_lines 1
    echo -e "\e[1;31m"Terraform plan failed. Fix the error and re-run the script."\e[0m"
    return 1
  fi
else
  print_empty_lines 1
  echo -n "Good bye."
  return 1
fi 


####################################
# Terraform apply
####################################

print_empty_lines 2
echo -n "Attention! The next step will deploy the launchpad Azure resources. If you are unsure which resource will be deployed, inspect the maint.tf file. Make sure that 'terraform plan' was successfully executed before. After executing the next step Terraform will place the state file into the local folder. Don't worry, we will migrate the state file to the final Azure backend in the last step. Would you like to deploy the resources now? (yes/no): "
read answer
print_empty_lines 1
if [ "$answer" == "yes" ]; then
  # Check if terraform plan file exists
  if [ -f "$TFPLANFILE" ]; then
    # Execute terraform apply and check if it was executed successfully
    if terraform apply -auto-approve $TFPLANFILE
    then
      print_empty_lines 1
      echo -e "\e[1;32m"Terraform apply executed successfully."\e[0m"
    else
      print_empty_lines 1
      echo -e "\e[1;31m"Terraform apply failed."\e[0m"
      return 1
    fi
  else
    print_empty_lines 1
    echo -e "\e[1;31m"Terraform plan file does not exist. Re-run the script and make sure you successfully complete the 'terraform plan' step."\e[0m"
    return 1
  fi
else
  print_empty_lines 1
  echo -n "Good bye."
  return 1
fi


####################################
# Configure Azure backend
####################################

print_empty_lines 2
echo -n "Now let us perform the last step of the process. It is time to copy the local Terraform state file to the new Azure backend storage. Would you like to continue? (yes/no): "
read answer

if [ "$answer" == "yes" ]; then

  RESOURCE_GROUP_NAME=$(terraform output resource_group_name)
  STORAGE_ACCOUNT_NAME=$(terraform output storage_account_name)
  CONTAINER_NAME=$(terraform output container_name)
  TENANT_ID=$(echo $TF_VAR_tenant_id)
  SUBSCRIPTION_ID=$(echo $TF_VAR_subscription_id)

  cat <<EOF > $TFBACKENDFILE
terraform {
  backend "azurerm" {
    tenant_id = "$TENANT_ID"
    subscription_id = "$SUBSCRIPTION_ID"
    resource_group_name = $RESOURCE_GROUP_NAME
    storage_account_name = $STORAGE_ACCOUNT_NAME
    container_name = $CONTAINER_NAME
    key = "terraform-launchpad.tfstate"
  }
}
EOF

  # Check if terraform plan file exists
  if [ -f "$TFPLANFILE" ]; then
    # Execute terraform init and check if it was executed successfully
    if terraform init <<EOF
yes
EOF
    then
      print_empty_lines 5
      echo -e "\e[1;32m"Congratulation! You successfully deployed all launchpad resources and configured Terraform to manage the state file in Azure. You may now manage your Azure resources using Terraform."\e[0m"
      print_empty_lines 2
      echo "   /\_/\\   "
      echo " =( °w° )= "
      echo "   )   (  //"
      echo "  (__ __)// "
      print_empty_lines 1
      echo "Have a me-wow day!"
      print_empty_lines 2        
      # some clean up
      echo "Removing local tfstate file."
      rm ./*.tfstate* >/dev/null 2>&1
    else
      echo -e "\e[1;32m"Setting up Azure backend failed."\e[0m"
      return 1
    fi
  else
    echo "\e[1;31m"This step was not executed. It seems that 'terraform plan' was not executed beforehand. The terraform plan file is missing in the local file system. Please re-run the the script."\e[0m"
    return 1
  fi
else
  print_empty_lines 1
  echo -n "Good bye."
  return 1
fi

####################################
# Some post deployment steps
####################################

terraform fmt >/dev/null 2>&1
rm -rvf *.tfplan >/dev/null 2>&1