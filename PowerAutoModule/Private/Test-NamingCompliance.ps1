function Test-NamingCompliance {
  param (
      [Parameter(Mandatory)]
      $Resource
  )

  $name = $Resource.Name
  $type = $Resource.ResourceType

  if ($type -like "*resourceGroups*") {
      return $name -like "rg-*"
  }
  elseif ($type -like "*virtualMachines*") {
      return $name -like "vm-*"
  }
  else {
      return $true
  }
}