# Terraform-Azure-Enterprise-Scale-Accelerator

This repository standardizes and automates:
1) the deployment of an Azure backend storage for Terraform state file management (Bridgehead)
2) a bootstrapping procedure for creating Terraform configuration files required by [terraform-azurerm-caf-enterprise-scale](https://github.com/Azure/terraform-azurerm-caf-enterprise-scale)

</br>

# In a Nutshell

You:
1) fill out **bootstrap.yaml**
2) execute **01_setup_bridgehead.sh**
3) execute **02_bootstrap_enterprise_scale.sh** and **Terraform** to deploy Enterprise Scale resources

Please read the next chapters for detailed instructions.

</br>

# Prepare Host for Setup Procedure

</br>

**1) Copy Content**
- Download a copy of this repo in your own [Github Organization](https://docs.github.com/en/organizations/collaborating-with-groups-in-organizations/about-organizations).

**2) Host**
- Clone your new repository to the machine on which the setup procedure will be executed (e.g. local notebook).

**3) Visual Studio Code**
- [Download](https://code.visualstudio.com/Download) and install Visual Studio Code (VSC).
- Enable [Devcontainer](https://code.visualstudio.com/docs/devcontainers/tutorial) on VSC.

**4) Devcontainer**
- Open VSC and click on the [Explorer](https://code.visualstudio.com/docs/getstarted/userinterface#_explorer) to open your repository. Choose [Reopen in Container](https://code.visualstudio.com/docs/devcontainers/create-dev-container#_add-configuration-files-to-a-repository) when prompted.
- VSC opens your workspace in a docker container.

</br>

# Setup Bridgehead

</br>

**5) Bridgehead Azure Subscription**
- Create an Azure [subscription](https://learn.microsoft.com/en-us/azure/cost-management-billing/manage/create-subscription) on which the Bridgehead resources will be deployed.

**6) Azure Automation User**
- Create an [Azure Service Principal](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal) which will be used as an automation user to authenticate to Azure.
- Assign the [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles) built-in role to the Service Principal with scope on the [Tenant Root Group](https://learn.microsoft.com/en-us/azure/governance/management-groups/overview).
- Create a Service Principal [secret](https://learn.microsoft.com/en-us/azure/active-directory/fundamentals/service-accounts-principal#service-principal-authentication).

**7) Installation**
- Execute **ignite.sh** to download the installation logic.
- Edit **bootstrap.yaml** according to your needs.
- Start the installation script by executing:
> ./**01_setup_bridgehead.sh** --client_id 'Service Principal Application/Client ID' --client_secret 'Service Principal Secret' --tenant_id 'Azure Active Directory Tenant ID' --subscription_id 'Subscription ID for Terraform Azure Backend'


**8) Azure Resources für Backend**
- The following Azure resource will be deployed as part of the Bridgehead:
  - Resource Group
  - Storage Account
  - Blob Container
  - Key Vault

**9) Terraform State File**
- In the last step of the installation procedure, the installation script will configure the [Azure Backend](https://developer.hashicorp.com/terraform/language/settings/backends/azurerm) to host the [Terraform state file](https://developer.hashicorp.com/terraform/language/state).

<br/>

# Setup Terraform Enterprise Scale
<br/>

**10) Settings**
- Adjust **bootstrap.yaml** according to your needs.

**11) Bootstrap Terraform Enterprise Scale**
- Start the script by executing
> ./**02_bootstrap_enterprise_scale.sh**

**12) Execute**
- The script creates the required Terraform Enterprise Scale files according to your inputs. Adjust the Terraform files if required.
- Continue by using standard Terraform commands such as **terraform init** and **terraform apply**.