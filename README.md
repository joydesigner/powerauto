
# PowerShell Automation Scripts

This repository contains PowerShell scripts for automating various DevOps tasks, particularly focused on Azure resources.

## Scripts

### ACR Image Remove Script (`Remove_ACRImages.ps1`)

This script automates the process of cleaning up old Docker images from an Azure Container Registry (ACR).

#### Features:
- Removes old images from specified ACR
- Configurable number of images to retain per repository
- Option to run in scan mode or deletion mode
- Can target a specific repository or all repositories in the registry

#### Usage:
```powershell
# Import the module
Import-Module ./PowerAutoModule

# Basic usage (dry run)
Remove-ACRImages -RegistryName "myregistry" -ImagesToKeep 5 -WhatIf

# Actual deletion
Remove-ACRImages -RegistryName "myregistry" -ImagesToKeep 5

# Clean specific repository
Remove-ACRImages -RegistryName "myregistry" -Repository "myapp" -ImagesToKeep 3

# With subscription specification
Remove-ACRImages -RegistryName "myregistry" -SubscriptionName "My Subscription" -ImagesToKeep 10

```

### Automated Azure VM Deployment & Configuration (`Deploy_VMs.ps1`)
Manually deploying and configuring virtual machines in Azure is time-consuming and prone to human error. Here is my code to PowerShell to automate VM creation, apply security policies, and install software.
#### Usage:
```powershell
# Import the module
Import-Module ./MyAzureDeploymentModule

# Deploy servers with all parameters
$params = @{
    ResourceGroupName   = "ProdRG"
    Location           = "EastUS"
    VmNames            = "WebServer01", "WebServer02", "WebServer03", "WebServer04", "WebServer05"
    VirtualNetworkName = "ProdVNet"
    SubnetName         = "Web"
    SecurityGroupName  = "WebSG"
    CustomScriptUri    = "https://example.com/install-app.ps1"
    CustomScriptCommand = "powershell.exe -ExecutionPolicy Bypass -File install-app.ps1"
}

Deploy-WebServers @params

# Or with minimal parameters
Deploy-WebServers -ResourceGroupName "ProdRG" -Location "EastUS" -VmNames @("WebServer01","WebServer02") `
                  -VirtualNetworkName "ProdVNet" -SubnetName "Web" -SecurityGroupName "WebSG"
```
