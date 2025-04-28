function Test-SecurityCompliance {
  param (
      [Parameter(Mandatory)]
      $Resource
  )

  if ($Resource.ResourceType -eq "Microsoft.Storage/storageAccounts") {
      $sa = Get-AzStorageAccount -Name $Resource.Name -ResourceGroupName $Resource.ResourceGroupName
      return $sa.EnableHttpsTrafficOnly
  }
  else {
      return $true
  }
}