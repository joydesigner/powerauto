# This script check and removes the old docker images from the azure container registry
# WARNING: this script will delete all image tags within a repository that share the same manifest


#region start function
function Remove-ACRImages {
  <#
    .SYNOPSIS
        Cleans up old images in Azure Container Registry.
    
    .DESCRIPTION
        Removes older image tags from Azure Container Registry repositories while keeping specified number of recent images.
    
    .PARAMETER RegistryName
        Name of the Azure Container Registry.
    
    .PARAMETER SubscriptionName
        Name of the Azure subscription (optional).
    
    .PARAMETER ImagesToKeep
        Number of recent images to retain per repository (default: 10).
    
    .PARAMETER Repository
        Specific repository to clean (optional, defaults to all repositories).
    
    .PARAMETER WhatIf
        Shows what would happen if the command runs without actually deleting.
    
    .EXAMPLE
        PS> Remove-ACROldImages -RegistryName "myacr" -ImagesToKeep 5
    
    .EXAMPLE
        PS> Remove-ACROldImages -RegistryName "myacr" -Repository "myapp" -WhatIf
    #>

  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistryName,
      
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionName,
      
    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$ImagesToKeep = 10,
      
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Repository
  )

  begin {
    # Validate Azure CLI installation 
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
      throw "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli."
    }

    # Validate Azure CLI login
    try {
      az account show | Out-Null
    }
    catch {
      throw "Azure CLI is not logged in. Please run 'az login'."
    }

    # Validate ACR existence
    try {
      $null = az acr show --name $RegistryName
    }
    catch {
      throw "Azure Container Registry '$RegistryName' not found or inaccessible."
    }

    # Set default subscription if specified
    if ($SubscriptionName) {
      try {
        Write-Verbose "Setting subscription to '$SubscriptionName'."
        az account set --subscription $SubscriptionName | Out-Null
      }
      catch {
        throw "Failed to set subscription '$SubscriptionName'. Please check the subscription name."
      }
    }

    $imagesDeleted = 0
    $repositoriesProcessed = 0
  }

  process {
    try {
      # Get repositories to process
      $repositories = if ($Repository) {
        Write-Verbose "Processing single repository: $Repository"
        @($Repository)
      }
      else {
        Write-Verbose "Getting all repositories in registry: $RegistryName"
          (az acr repository list --name $RegistryName --output tsv)
      }

      foreach ($repo in $repositories) {
        $repositoriesProcessed++
        Write-Verbose "Processing repository: $repo"
          
        # Get tags sorted by time (newest first)
        $tags = az acr repository show-tags --name $RegistryName --repository $repo --orderby time_desc --output tsv
          
        Write-Verbose "Found $($tags.Count) images in repository '$repo' (keeping $ImagesToKeep)"
          
        if ($tags.Count -gt $ImagesToKeep) {
          $tagsToDelete = $tags | Select-Object -Skip $ImagesToKeep
              
          foreach ($tag in $tagsToDelete) {
            $imageName = "${repo}:$tag"
            $imagesDeleted++
                  
            if ($PSCmdlet.ShouldProcess($imageName, "Delete image")) {
              Write-Verbose "Deleting: $imageName"
              $null = az acr repository delete --name $RegistryName --image $imageName --yes
            }
            else {
              Write-Verbose "[WhatIf] Would delete: $imageName"
            }
          }
        }
        else {
          Write-Verbose "No surplus images to delete in repository '$repo'"
        }
      }
    }
    catch {
      Write-Error "Error during processing: $_"
      throw
    }
  }

  end {
    # Create a summary object instead of just writing to output
    $summary = [PSCustomObject]@{
      RegistryName        = $RegistryName
      RepositoriesScanned = $repositoriesProcessed
      ImagesDeleted       = $imagesDeleted
      OperationMode       = if ($PSCmdlet.ShouldProcess("")) { "Actual Deletion" } else { "WhatIf Simulation" }
      Timestamp           = [DateTime]::Now
    }

    # Output the summary
    $summary

    # Detailed verbose logging
    Write-Verbose "ACR cleanup completed at $($summary.Timestamp)"
    Write-Verbose "Registry: $($summary.RegistryName)"
    Write-Verbose "Repositories scanned: $($summary.RepositoriesScanned)"
    Write-Verbose "Images deleted: $($summary.ImagesDeleted)"
    Write-Verbose "Mode: $($summary.OperationMode)"
  }
}
#endregion

