function Deploy-VMs {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
      
    [Parameter(Mandatory = $true)]
    [string]$Location,
      
    [Parameter(Mandatory = $true)]
    [string[]]$VmNames,
      
    [Parameter(Mandatory = $true)]
    [string]$VirtualNetworkName,
      
    [Parameter(Mandatory = $true)]
    [string]$SubnetName,
      
    [Parameter(Mandatory = $true)]
    [string]$SecurityGroupName,
      
    [Parameter(Mandatory = $false)]
    [int[]]$OpenPorts = @(80, 443),
      
    [Parameter(Mandatory = $false)]
    [string]$CustomScriptUri,
      
    [Parameter(Mandatory = $false)]
    [string]$CustomScriptCommand
  )

  begin {
    # Validate Azure connection
    if (-not (Get-AzContext)) {
      throw "Not connected to Azure. Please run Connect-AzAccount first."
    }
  }

  process {
    foreach ($name in $VmNames) {
      try {
        Write-Output "Creating VM: $name"
              
        # Create VM
        $vmParams = @{
          ResourceGroupName   = $ResourceGroupName
          Name                = $name
          Location            = $Location
          VirtualNetworkName  = $VirtualNetworkName
          SubnetName          = $SubnetName
          SecurityGroupName   = $SecurityGroupName
          PublicIpAddressName = "$name-IP"
          OpenPorts           = $OpenPorts
        }
              
        New-AzVm @vmParams
              
        # Add extension if script URI provided
        if ($CustomScriptUri) {
          Write-Output "Installing custom script extension on $name"
                  
          $extensionSettings = @{
            fileUris         = @($CustomScriptUri)
            commandToExecute = $CustomScriptCommand
          }
                  
          Set-AzVMExtension -ResourceGroupName $ResourceGroupName `
            -VMName $name `
            -Name "CustomScript" `
            -Publisher "Microsoft.Compute" `
            -ExtensionType "CustomScriptExtension" `
            -TypeHandlerVersion 1.10 `
            -Settings $extensionSettings
        }
              
        Write-Output "Successfully deployed $name"
      }
      catch {
        Write-Error ("Failed to deploy {0}: {1}" -f $name, $_)
        # Optionally continue with next VM
        continue
      }
    }
  }

  end {
    Write-Output "Web server deployment completed"
  }
}