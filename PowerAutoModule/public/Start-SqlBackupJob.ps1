# This script is part of the PowerAutoModule project.
# It is designed to automate SQL Server database backup operations.
function Start-SqlBackupJob {
  <#
  .SYNOPSIS
      Performs automated SQL Server database backups with verification.
  
  .DESCRIPTION
      Creates full database backups with optional compression, verification,
      and retention policy enforcement.
  
  .PARAMETER SqlInstance
      SQL Server instance name.
  
  .PARAMETER BackupPath
      Root directory for backup files.
  
  .PARAMETER RetentionDays
      Number of days to keep backups (default: 30).
  
  .PARAMETER Compression
      Enable backup compression (default: true).
  
  .PARAMETER Verify
      Verify backup integrity after creation (default: true).
  
  .PARAMETER LogPath
      Path for backup log files.
  
  .PARAMETER WhatIf
      Shows what would happen without actually making changes.
  
  .EXAMPLE
      PS> Start-SqlBackupJob -SqlInstance "SQLServer01" -BackupPath "\\backupserver\SQLBackups"
  
  .EXAMPLE
      PS> Start-SqlBackupJob -SqlInstance "SQLServer01" -BackupPath "D:\SQLBackups" -RetentionDays 14 -Compression $false
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory)]
    [string]$SqlInstance,
      
    [Parameter(Mandatory)]
    [string]$BackupPath,
      
    [Parameter()]
    [int]$RetentionDays = 30,
      
    [Parameter()]
    [bool]$Compression = $true,
      
    [Parameter()]
    [bool]$Verify = $true,
      
    [Parameter()]
    [string]$LogPath,
      
    [Parameter()]
    [string[]]$ExcludeDatabases = @("tempdb", "model")
  )

  begin {
    # Validate SQL Server connection
    try {
      $null = Get-SqlInstance -ServerInstance $SqlInstance -ErrorAction Stop
    }
    catch {
      throw "Failed to connect to SQL Server instance '$SqlInstance': $_"
    }

    # Initialize statistics
    $stats = [PSCustomObject]@{
      StartTime        = [DateTime]::Now
      Databases        = 0
      SuccessCount     = 0
      FailedCount      = 0
      BackupSizeMB     = 0
      OldBackupsPurged = 0
    }

    # Create backup directory with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fullBackupPath = Join-Path $BackupPath "$($SqlInstance)_$timestamp"
      
    try {
      if ($PSCmdlet.ShouldProcess($fullBackupPath, "Create backup directory")) {
        $null = New-Item -Path $fullBackupPath -ItemType Directory -Force
      }
    }
    catch {
      throw "Failed to create backup directory: $_"
    }

    # Initialize log file if specified
    if ($LogPath) {
      try {
        $logHeader = "Timestamp,Database,BackupFile,Status,SizeMB,Verification,Error"
        $logHeader | Out-File -FilePath $LogPath -Force -Append
      }
      catch {
        Write-Warning "Failed to initialize log file: $_"
      }
    }
  }

  process {
    try {
      # Get databases to back up (excluding system databases)
      $databases = Get-SqlDatabase -ServerInstance $SqlInstance | 
      Where-Object { $_.Name -notin $ExcludeDatabases -and $_.Status -eq "Normal" }
          
      $stats.Databases = $databases.Count

      foreach ($db in $databases) {
        $dbName = $db.Name
        $backupFile = "$($dbName)_$timestamp.bak"
        $backupFilePath = Join-Path $fullBackupPath $backupFile
        $verificationResult = $null

        try {
          if ($PSCmdlet.ShouldProcess($dbName, "Create database backup")) {
            # Perform backup
            $backupParams = @{
              ServerInstance = $SqlInstance
              Database       = $dbName
              BackupFile     = $backupFilePath
              Initialize     = $true
            }

            if ($Compression) {
              $backupParams.CompressionOption = "On"
            }

            Backup-SqlDatabase @backupParams -ErrorAction Stop
                      
            # Get backup size
            $backupSize = (Get-Item $backupFilePath).Length / 1MB
            $stats.BackupSizeMB += $backupSize

            # Verify backup if requested
            if ($Verify) {
              try {
                $verifyResult = Test-SqlBackup -ServerInstance $SqlInstance -Database $dbName -BackupFile $backupFilePath
                $verificationResult = if ($verifyResult.Status -eq "Success") { "Verified" } else { "Failed" }
              }
              catch {
                $verificationResult = "VerificationError"
                throw
              }
            }

            $stats.SuccessCount++
            Log-BackupOperation -Database $dbName -BackupFile $backupFilePath -Status "Success" -SizeMB $backupSize -Verification $verificationResult -LogPath $LogPath
          }
        }
        catch {
          $stats.FailedCount++
          Log-BackupOperation -Database $dbName -BackupFile $backupFilePath -Status "Failed" -Error $_ -LogPath $LogPath
          Write-Error "Failed to back up database '$dbName': $_"
          continue
        }
      }

      # Apply retention policy
      if ($RetentionDays -gt 0) {
        try {
          $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
          $oldBackups = Get-ChildItem $BackupPath -Directory | 
          Where-Object { $_.Name -like "$($SqlInstance)_*" -and $_.CreationTime -lt $cutoffDate }
                  
          foreach ($backupDir in $oldBackups) {
            if ($PSCmdlet.ShouldProcess($backupDir.FullName, "Remove old backup")) {
              Remove-Item -Path $backupDir.FullName -Recurse -Force
              $stats.OldBackupsPurged++
            }
          }
        }
        catch {
          Write-Warning "Failed to clean up old backups: $_"
        }
      }
    }
    catch {
      throw "Backup process failed: $_"
    }
  }

  end {
    # Complete statistics
    $stats.EndTime = [DateTime]::Now
    $stats.Duration = $stats.EndTime - $stats.StartTime

    # Output summary
    Write-Output "`nBackup Job Completed:"
    Write-Output "  SQL Instance:      $SqlInstance"
    Write-Output "  Backup Path:       $fullBackupPath"
    Write-Output "  Databases:         $($stats.Databases)"
    Write-Output "  Successful:        $($stats.SuccessCount)"
    Write-Output "  Failed:            $($stats.FailedCount)"
    Write-Output "  Total Size (MB):   $([math]::Round($stats.BackupSizeMB, 2))"
    Write-Output "  Old Backups Purged: $($stats.OldBackupsPurged)"
    Write-Output "  Start Time:        $($stats.StartTime)"
    Write-Output "  End Time:          $($stats.EndTime)"
    Write-Output "  Duration:          $($stats.Duration.ToString('hh\:mm\:ss'))"

    return $stats
  }
}

function Log-BackupOperation {
  param (
    [string]$Database,
    [string]$BackupFile,
    [string]$Status,
    [double]$SizeMB,
    [string]$Verification,
    [string]$ErrorMessage,
    [string]$LogPath
  )

  if ($LogPath) {
    try {
      $logEntry = "$([DateTime]::Now),$Database,$BackupFile,$Status,$([math]::Round($SizeMB, 2)),$Verification,$ErrorMessage"
      $logEntry | Out-File -FilePath $LogPath -Append
    }
    catch {
      Write-Warning "Failed to write to log file: $_"
    }
  }
}

function Test-SqlBackup {
  param (
    [string]$ServerInstance,
    [string]$Database,
    [string]$BackupFile
  )

  try {
    Restore-SqlDatabase -ServerInstance $ServerInstance -Database "${Database}_Verify" `
      -BackupFile $BackupFile -NoRecovery -RestoreAction Database -ErrorAction Stop
      
    # Clean up
    $null = Remove-SqlDatabase -ServerInstance $ServerInstance -Database "${Database}_Verify" -ErrorAction SilentlyContinue
      
    return [PSCustomObject]@{
      Status  = "Success"
      Message = "Backup verified successfully"
    }
  }
  catch {
    return [PSCustomObject]@{
      Status  = "Failed"
      Message = $_
    }
  }
}