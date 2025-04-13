# PowerAutoModule.psm1
# Dot-source all public functions
Get-ChildItem -Path $PSScriptRoot/Public/*.ps1 | ForEach-Object {
  . $_.FullName
}

Export-ModuleMember -Function (Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1").BaseName