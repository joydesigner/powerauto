function Set-NewHirePassword {
  <#
  .SYNOPSIS
      Forces a password reset for new hires.
  
  .DESCRIPTION
      Sets the "Change password at next logon" flag for specified users.
  
  .PARAMETER SamAccountNames
      Array of user SAM account names.
  
  .EXAMPLE
      PS> Set-NewHirePassword -SamAccountNames "jdoe","bsmith"
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
      [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
      [string[]]$SamAccountNames
  )

  process {
      foreach ($user in $SamAccountNames) {
          if ($PSCmdlet.ShouldProcess($user, "Set password change at next logon")) {
              try {
                  Set-ADUser -Identity $user -ChangePasswordAtLogon $true -ErrorAction Stop
                  Write-Verbose "Password reset required for $user"
              }
              catch {
                  Write-Error "Failed to set password reset for $user : $_"
              }
          }
          else {
              Write-Output "[WhatIf] Would require password change for $user"
          }
      }
  }
}