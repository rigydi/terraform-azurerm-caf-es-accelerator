<div hidden>
@startuml Diagram
!define AzurePuml https://raw.githubusercontent.com/plantuml-stdlib/Azure-PlantUML/release/2-2/dist
!define SPRITESURL https://raw.githubusercontent.com/plantuml-stdlib/gilbarbara-plantuml-sprites/v1.0/sprites

!includeurl AzurePuml/AzureSimplified.puml
!includeurl AzurePuml/AzureCommon.puml

skinparam rectangleBackgroundColor transparent
skinparam defaultFontColor grey
skinparam handwritten true
left to right direction
actor "Person" as user

' #####################################
' # Preparations
' #####################################

rectangle "Preparation" as preparation {

  ' Docker
  !includeurl SPRITESURL/docker.puml
  rectangle "<color:blue><$docker></color> Devcontainer" as devcontainer

  ' Github
  !includeurl SPRITESURL/github.puml
  rectangle "<color:black><$github></color>" as github

  ' Visual Studio
  rectangle "Visual Studio Code" as vsc

  ' Azure Virtual Machine
  !includeurl AzurePuml/Compute/AzureVirtualMachine.puml
  rectangle "<color:AZURE_SYMBOL_COLOR><$AzureVirtualMachine></color> Execution Host" as machine
}

' #####################################
' # Launchpad Setup Procedure
' #####################################

rectangle "Launchpad (LP) - Setup Procedure" as launchpad {
  ' Azure Subscription
  !includeurl AzurePuml/Management/AzureSubscription.puml
  rectangle "<color:#ab9100><$AzureSubscription></color> Subscription" as subscription

  ' Azure User
  !includeurl AzurePuml/Identity/AzureActiveDirectoryUser.puml
  rectangle "<color:AZURE_SYMBOL_COLOR><$AzureActiveDirectoryUser></color> Service Principal" as spn

  ' Shell Script
  file "Setup Script" as setuplp

  ' Terraform
  !includeurl SPRITESURL/terraform.puml
  rectangle "<color:purple><$terraform></color> terraform.exe" as terraform

  rectangle "Launchpad Azure Resources" as azresources {

    ' Resource Group
    !includeurl AzurePuml/Management/AzureResourceGroups.puml
    rectangle "<color:AZURE_SYMBOL_COLOR><$AzureResourceGroups></color> LP Resource Group" as resgroup

    ' Storage Account
    !includeurl AzurePuml/Storage/AzureStorage.puml
    rectangle "<color:AZURE_SYMBOL_COLOR><$AzureStorage></color> LP Storage Account" as straccount

    ' TF-CAF-ES Blob Container
    !includeurl AzurePuml/Storage/AzureBlobStorage.puml
    rectangle "<color:orange><$AzureBlobStorage></color> TF-CAF-ES Blob Container (Terraform state)" as blobtfcafes
  }
}


user -> github: 1) forks repo to own Github organization
user -> machine: 2) clones repo to execution host
user -> vsc: 3) opens repo in

vsc .> machine: is running on
vsc .> devcontainer: opens
devcontainer .> setuplp: contains

user --> devcontainer: 4) connects to
user --> subscription: 5) creates
user --> spn: 6) creates and assigns role
user ---> setuplp: 7) executes

setuplp --> azresources: 8) creates
setuplp --> blobtfcafes: 9) copies TF state file to
setuplp .> terraform: uses

resgroup .> straccount: contains
straccount ..> blobtfcafes: contains



' #####################################
' # TF-CAF-ES-Accelerator
' #####################################

rectangle "TF-CAF-ES-Accelerator - Setup Procedure" as accelerator {
  'Settings File
  file "Settings File" as settingsaccelerator

  'Shell Script
  file "Setup Script" as setupaccelerator

  ' Terraform
  !includeurl SPRITESURL/terraform.puml
  rectangle "<color:purple><$terraform></color> tf-caf-es config files" as terraformaccelerator
}

user --> settingsaccelerator: 10) edits
devcontainer ..> settingsaccelerator: contains
devcontainer ..> setupaccelerator: contains
user --> setupaccelerator: 11) executes
setupaccelerator -> terraformaccelerator: 12) creates configuration files
setupaccelerator ..> settingsaccelerator: uses
@enduml
</div>

![](diagram.svg)