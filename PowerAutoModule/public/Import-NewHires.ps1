function Import-NewHires {
  <#
  .SYNOPSIS
      Creates new AD users from a CSV file and assigns them to groups.
  
  .DESCRIPTION
      Automates the onboarding process by creating user accounts, setting initial passwords,
      and adding users to specified security groups.
  
  .PARAMETER CsvPath
      Path to the CSV file containing new hire information.
  
  .PARAMETER DefaultPassword
      Initial password for new accounts (will require reset at first login).
  
  .PARAMETER Groups
      Security groups to add the users to.
  
  .PARAMETER Domain
      Company domain for UPN creation.
  
  .PARAMETER WhatIf
      Shows what would happen without actually making changes.
  
  .EXAMPLE
      PS> Import-NewHires -CsvPath "C:\HR\NewHires.csv" -Groups "FinanceDept","AllEmployees"
  
  .EXAMPLE
      PS> Import-NewHires -CsvPath "C:\HR\NewHires.csv" -DefaultPassword "P@ssw0rd123!" -Domain "company.com" -WhatIf
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
      [Parameter(Mandatory)]
      [ValidateScript({Test-Path $_ -PathType Leaf})]
      [string]$CsvPath,
      
      [Parameter()]
      [ValidateNotNullOrEmpty()]
      [string]$DefaultPassword = "TempP@ssw0rd!",
      
      [Parameter()]
      [string[]]$Groups = @("FinanceDept"),
      
      [Parameter()]
      [ValidatePattern("\.[a-z]{2,}$")]
      [string]$Domain = "company.com",
      
      [Parameter()]
      [string]$OU = "OU=Users,DC=company,DC=com"
  )

  begin {
      # Initialize counters
      $usersCreated = 0
      $failures = 0
      $results = @()
      
      # Validate Active Directory module
      if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
          throw "Active Directory module is not available. Please install RSAT-AD-PowerShell."
      }
  }

  process {
      try {
          $newHires = Import-Csv -Path $CsvPath
          
          foreach ($hire in $newHires) {
              $userParams = @{
                  SamAccountName        = $hire.SamAccountName
                  Name                  = $hire.Name
                  GivenName             = $hire.GivenName
                  Surname               = $hire.Surname
                  UserPrincipalName     = "$($hire.SamAccountName)@$Domain"
                  AccountPassword       = (ConvertTo-SecureString $DefaultPassword -AsPlainText -Force)
                  Enabled               = $true
                  ChangePasswordAtLogon = $true
                  Path                  = $OU
                  OtherAttributes       = @{
                      employeeID = $hire.EmployeeID
                      title      = $hire.JobTitle
                  }
              }

              if ($PSCmdlet.ShouldProcess($hire.SamAccountName, "Create AD user")) {
                  try {
                      # Create user
                      New-ADUser @userParams -ErrorAction Stop
                      
                      # Add to groups
                      foreach ($group in $Groups) {
                          Add-ADGroupMember -Identity $group -Members $hire.SamAccountName -ErrorAction Stop
                      }
                      
                      $usersCreated++
                      $results += [PSCustomObject]@{
                          SamAccountName = $hire.SamAccountName
                          Status        = "Success"
                          Groups        = $Groups -join ","
                          Timestamp     = [DateTime]::Now
                      }
                  }
                  catch {
                      $failures++
                      $results += [PSCustomObject]@{
                          SamAccountName = $hire.SamAccountName
                          Status        = "Failed: $_"
                          Groups        = ""
                          Timestamp     = [DateTime]::Now
                      }
                      Write-Error "Failed to create $($hire.SamAccountName): $_"
                  }
              }
              else {
                  Write-Output "[WhatIf] Would create user: $($hire.SamAccountName)"
                  Write-Output "[WhatIf] Would add to groups: $($Groups -join ', ')"
              }
          }
      }
      catch {
          Write-Error "Failed to process CSV file: $_"
          throw
      }
  }

  end {
      # Generate summary report
      $summary = [PSCustomObject]@{
          TotalUsers    = $newHires.Count
          UsersCreated  = $usersCreated
          Failures      = $failures
          RunDate       = [DateTime]::Now
          CsvFile       = $CsvPath
      }

      # Output results
      $summary
      $results | Format-Table -AutoSize
      
      # Optionally export results to CSV
      $reportPath = Join-Path (Split-Path $CsvPath) "OnboardingReport_$(Get-Date -Format yyyyMMdd).csv"
      $results | Export-Csv -Path $reportPath -NoTypeInformation
  }
}