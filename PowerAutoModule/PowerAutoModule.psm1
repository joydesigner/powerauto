# PowerAutoModule.psm1
$separator = [System.IO.Path]::DirectorySeparatorChar
# Dot-source all public functions
Get-ChildItem -Path "$PSScriptRoot${separator}Public${separator}*.ps1" | ForEach-Object {
  . $_.FullName
}

# Dot-source all private functions
Get-ChildItem -Path "$PSScriptRoot${separator}Private${separator}*.ps1" | ForEach-Object {
  . $_.FullName
}

# Export only public functions
Export-ModuleMember -Function (Get-ChildItem -Path "$PSScriptRoot${separator}Public${separator}*.ps1").BaseName