# PowerShell Automation Scripts

This repository contains PowerShell scripts for automating various DevOps tasks, particularly focused on Azure resources.

## Scripts

### ACR Cleanup Script (`acr_clean.ps1`)

This script automates the process of cleaning up old Docker images from an Azure Container Registry (ACR).

#### Features:
- Removes old images from specified ACR
- Configurable number of images to retain per repository
- Option to run in scan mode or deletion mode
- Can target a specific repository or all repositories in the registry

#### Usage:
```powershell
.\acr_clean.ps1 -AzureRegistryName <registry-name> [-SubscriptionName <subscription-name>] [-ImagestoKeep <number>] [-EnableDelete <yes/no>] [-Repository <repository-name>]