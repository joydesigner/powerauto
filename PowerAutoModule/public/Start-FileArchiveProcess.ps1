# Module for automated file archiving
function Start-FileArchiveProcess {
  <#
  .SYNOPSIS
      Archives files older than specified days and optionally removes duplicates.
  
  .DESCRIPTION
      Moves files meeting age criteria to an archive location, with options for compression,
      logging, and duplicate removal. Supports WhatIf scenarios for testing.
  
  .PARAMETER SourcePath
      Path to the directory containing files to archive.
  
  .PARAMETER ArchivePath
      Destination path for archived files.
  
  .PARAMETER DaysOld
      Age threshold in days for archiving (default: 90).
  
  .PARAMETER RemoveDuplicates
      Switch to enable duplicate file removal.
  
  .PARAMETER CompressArchives
      Switch to compress archived files into ZIP format.
  
  .PARAMETER LogPath
      Path to save operation logs (optional).
  
  .PARAMETER WhatIf
      Shows what would happen without actually making changes.
  
  .PARAMETER Confirm
      Prompts for confirmation before each operation.
  
  .EXAMPLE
      PS> Start-FileArchiveProcess -SourcePath "\\fileserver\shared" -ArchivePath "\\fileserver\archive" -DaysOld 180
  
  .EXAMPLE
      PS> Start-FileArchiveProcess -SourcePath "C:\Projects" -ArchivePath "D:\Archives" -RemoveDuplicates -CompressArchives -WhatIf
  #>
  [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
  param (
    [Parameter(Mandatory)]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Container)) {
          throw "Source path does not exist or is not a directory"
        }
        $true
      })]
    [string]$SourcePath,
      
    [Parameter(Mandatory)]
    [string]$ArchivePath,
      
    [Parameter()]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$DaysOld = 90,
      
    [Parameter()]
    [switch]$RemoveDuplicates,
      
    [Parameter()]
    [switch]$CompressArchives,
      
    [Parameter()]
    [string]$LogPath
  )

  begin {
    # Initialize counters and logs
    $stats = [PSCustomObject]@{
      FilesProcessed    = 0
      FilesArchived     = 0
      DuplicatesRemoved = 0
      ErrorsOccurred    = 0
      StartTime         = [DateTime]::Now
    }

    # Create archive directory if needed
    if (-not (Test-Path $ArchivePath)) {
      try {
        $null = New-Item -Path $ArchivePath -ItemType Directory -Force
        Write-Verbose "Created archive directory: $ArchivePath"
      }
      catch {
        throw "Failed to create archive directory: $_"
      }
    }

    # Initialize log file if specified
    if ($LogPath) {
      try {
        $logHeader = "Timestamp,Operation,Path,Result"
        $logHeader | Out-File -FilePath $LogPath -Force
      }
      catch {
        Write-Warning "Failed to initialize log file: $_"
      }
    }

    # Calculate cutoff date
    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    Write-Verbose "Archiving files older than $cutoffDate"
  }

  process {
    try {
      # Archive old files
      Write-Verbose "Processing files in: $SourcePath"
      $filesToArchive = Get-ChildItem -Path $SourcePath -Recurse -File | 
      Where-Object { $_.LastWriteTime -lt $cutoffDate }

      foreach ($file in $filesToArchive) {
        $stats.FilesProcessed++
        $relativePath = $file.FullName.Substring($SourcePath.Length)
        $destinationPath = Join-Path $ArchivePath $relativePath
        $destinationDir = [System.IO.Path]::GetDirectoryName($destinationPath)

        try {
          # Create destination directory structure
          if (-not (Test-Path $destinationDir)) {
            if ($PSCmdlet.ShouldProcess($destinationDir, "Create directory")) {
              $null = New-Item -Path $destinationDir -ItemType Directory -Force
            }
          }

          # Move or compress file
          if ($CompressArchives) {
            $zipPath = $destinationPath + ".zip"
            if ($PSCmdlet.ShouldProcess($file.FullName, "Compress to $zipPath")) {
              Compress-Archive -Path $file.FullName -DestinationPath $zipPath -CompressionLevel Optimal
              Remove-Item -Path $file.FullName -Force
              $stats.FilesArchived++
              Log-Operation -Message "Compressed and archived" -Path $file.FullName -LogPath $LogPath
            }
          }
          else {
            if ($PSCmdlet.ShouldProcess($file.FullName, "Move to $destinationPath")) {
              Move-Item -Path $file.FullName -Destination $destinationPath -Force
              $stats.FilesArchived++
              Log-Operation -Message "Archived" -Path $file.FullName -LogPath $LogPath
            }
          }
        }
        catch {
          $stats.ErrorsOccurred++
          Log-Operation -Message "Error: $_" -Path $file.FullName -LogPath $LogPath -IsError
          Write-Warning "Failed to process $($file.FullName): $_"
        }
      }

      # Remove duplicates if requested
      if ($RemoveDuplicates) {
        Write-Verbose "Checking for duplicate files in: $SourcePath"
        $duplicateStats = Remove-DuplicateFiles -Path $SourcePath -LogPath $LogPath -WhatIf:$WhatIfPreference
        $stats.DuplicatesRemoved = $duplicateStats.DuplicatesRemoved
        $stats.ErrorsOccurred += $duplicateStats.ErrorsOccurred
      }
    }
    catch {
      $stats.ErrorsOccurred++
      Log-Operation -Message "Fatal error: $_" -Path $SourcePath -LogPath $LogPath -IsError
      throw "Archive process failed: $_"
    }
  }

  end {
    # Complete statistics
    $stats.EndTime = [DateTime]::Now
    $stats.Duration = $stats.EndTime - $stats.StartTime

    # Output summary
    Write-Output "`nArchive Process Completed:"
    Write-Output "  Files Processed:  $($stats.FilesProcessed)"
    Write-Output "  Files Archived:   $($stats.FilesArchived)"
    Write-Output "  Duplicates Removed: $($stats.DuplicatesRemoved)"
    Write-Output "  Errors Occurred:  $($stats.ErrorsOccurred)"
    Write-Output "  Start Time:       $($stats.StartTime)"
    Write-Output "  End Time:         $($stats.EndTime)"
    Write-Output "  Duration:         $($stats.Duration.ToString('hh\:mm\:ss'))"

    # Final log entry
    Log-Operation -Message "Process completed" -Path $SourcePath -LogPath $LogPath -Stats $stats

    return $stats
  }
}

function Log-Operation {
  param (
    [string]$Message,
    [string]$Path,
    [string]$LogPath,
    [bool]$IsError = $false,
    [pscustomobject]$Stats
  )

  if ($LogPath) {
    try {
      $logEntry = "$([DateTime]::Now),$Message,$Path,$(if ($IsError) {'ERROR'} else {'SUCCESS'})"
      $logEntry | Out-File -FilePath $LogPath -Append
    }
    catch {
      Write-Warning "Failed to write to log file: $_"
    }
  }
}