# This script is part of the PowerAutoModule project.
# It provides a function to remove duplicate files based on hash comparison.
function Remove-DuplicateFiles {
  <#
  .SYNOPSIS
      Removes duplicate files based on hash comparison.
  
  .DESCRIPTION
      Identifies and removes duplicate files by comparing SHA256 hashes.
      Preserves the first occurrence of each file and removes subsequent duplicates.
  
  .PARAMETER Path
      Directory path to search for duplicates.
  
  .PARAMETER Algorithm
      Hashing algorithm to use (default: SHA256).
  
  .PARAMETER LogPath
      Path to save operation logs (optional).
  
  .PARAMETER WhatIf
      Shows what would happen without actually making changes.
  
  .EXAMPLE
      PS> Remove-DuplicateFiles -Path "\\fileserver\shared" -Algorithm MD5
  
  .EXAMPLE
      PS> Get-ChildItem -Path "C:\Projects" -Directory | Remove-DuplicateFiles -WhatIf
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [ValidateScript({
        if (-not (Test-Path $_)) {
          throw "Path does not exist"
        }
        $true
      })]
    [string]$Path,
      
    [Parameter()]
    [ValidateSet("SHA1", "SHA256", "SHA384", "SHA512", "MD5")]
    [string]$Algorithm = "SHA256",
      
    [Parameter()]
    [string]$LogPath
  )

  begin {
    $hashes = @{}
    $stats = [PSCustomObject]@{
      FilesProcessed    = 0
      DuplicatesRemoved = 0
      ErrorsOccurred    = 0
    }
  }

  process {
    try {
      Write-Verbose "Checking for duplicates in: $Path"
      $files = Get-ChildItem -Path $Path -File -Recurse
          
      foreach ($file in $files) {
        $stats.FilesProcessed++
        try {
          $hash = Get-FileHash -Path $file.FullName -Algorithm $Algorithm -ErrorAction Stop
                  
          if ($hashes.ContainsKey($hash.Hash)) {
            if ($PSCmdlet.ShouldProcess($file.FullName, "Remove duplicate")) {
              Remove-Item -Path $file.FullName -Force -ErrorAction Stop
              $stats.DuplicatesRemoved++
              Log-Operation -Message "Removed duplicate" -Path $file.FullName -LogPath $LogPath
            }
          }
          else {
            $hashes[$hash.Hash] = $file.FullName
          }
        }
        catch {
          $stats.ErrorsOccurred++
          Log-Operation -Message "Error: $_" -Path $file.FullName -LogPath $LogPath -IsError
          Write-Warning "Failed to process $($file.FullName): $_"
        }
      }
    }
    catch {
      $stats.ErrorsOccurred++
      Log-Operation -Message "Fatal error: $_" -Path $Path -LogPath $LogPath -IsError
      throw "Duplicate removal failed: $_"
    }
  }

  end {
    Write-Output "`nDuplicate Removal Completed:"
    Write-Output "  Files Processed:  $($stats.FilesProcessed)"
    Write-Output "  Duplicates Removed: $($stats.DuplicatesRemoved)"
    Write-Output "  Errors Occurred:  $($stats.ErrorsOccurred)"
      
    return $stats
  }
}