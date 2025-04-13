# This script is part of the PowerAutoModule project.
# It is designed to test SQL Server database restore operations from backup files.
function Test-SqlRestore {
  <#
  .SYNOPSIS
      Tests database restore from backup files.
  
  .DESCRIPTION
      Performs test restores of databases to verify backup integrity.
      Can be scheduled to run periodically.
  
  .PARAMETER SourceInstance
      Source SQL Server instance name.
  
  .PARAMETER TestInstance
      Test SQL Server instance for restore operations.
  
  .PARAMETER BackupPath
      Path containing backup files.
  
  .PARAMETER Databases
      Specific databases to test (default: all found in backup path).
  
  .PARAMETER LatestOnly
      Only test the most recent backup for each database.
  
  .PARAMETER LogPath
      Path for restore test logs.
  
  .PARAMETER WhatIf
      Shows what would happen without actually making changes.
  
  .EXAMPLE
      PS> Test-SqlRestore -SourceInstance "SQLProd01" -TestInstance "SQLTest01" -BackupPath "\\backupserver\SQLBackups"
  
  .EXAMPLE
      PS> Test-SqlRestore -SourceInstance "SQLProd01" -TestInstance "SQLTest01" -BackupPath "D:\SQLBackups" -Databases "OrdersDB","CustomersDB" -LatestOnly
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory)]
    [string]$SourceInstance,
      
    [Parameter(Mandatory)]
    [string]$TestInstance,
      
    [Parameter(Mandatory)]
    [string]$BackupPath,
      
    [Parameter()]
    [string[]]$Databases,
      
    [Parameter()]
    [switch]$LatestOnly,
      
    [Parameter()]
    [string]$LogPath
  )

  begin {
    # Initialize statistics
    $stats = [PSCustomObject]@{
      StartTime     = [DateTime]::Now
      BackupsTested = 0
      SuccessCount  = 0
      FailedCount   = 0
    }

    # Initialize log file if specified
    if ($LogPath) {
      try {
        $logHeader = "Timestamp,SourceInstance,TestInstance,Database,BackupFile,BackupDate,Status,Error"
        $logHeader | Out-File -FilePath $LogPath -Force -Append
      }
      catch {
        Write-Warning "Failed to initialize log file: $_"
      }
    }

    # Find backup files
    $backupFiles = Get-ChildItem -Path $BackupPath -Recurse -Filter "*.bak"
      
    if (-not $backupFiles) {
      throw "No backup files found in $BackupPath"
    }

    # Group by database if LatestOnly specified
    if ($LatestOnly) {
      $backupFiles = $backupFiles | Group-Object { $_.BaseName.Split('_')[0] } | 
      ForEach-Object { $_.Group | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
    }

    # Filter by specified databases if provided
    if ($Databases) {
      $backupFiles = $backupFiles | Where-Object { 
        $dbName = $_.BaseName.Split('_')[0]
        $Databases -contains $dbName
      }
    }
  }

  process {
    try {
      foreach ($backupFile in $backupFiles) {
        $stats.BackupsTested++
        $dbName = $backupFile.BaseName.Split('_')[0]
        $testDbName = "${dbName}_TestRestore"
        $backupDate = $backupFile.LastWriteTime.ToString("yyyyMMdd")
        $errorMsg = $null

        try {
          if ($PSCmdlet.ShouldProcess($dbName, "Test restore from $($backupFile.Name)")) {
            # Restore database with new name
            $restoreParams = @{
              ServerInstance  = $TestInstance
              Database        = $testDbName
              BackupFile      = $backupFile.FullName
              ReplaceDatabase = $true
            }

            Restore-SqlDatabase @restoreParams -ErrorAction Stop
                      
            # Verify database is accessible
            $query = "SELECT COUNT(*) FROM sys.tables"
            Invoke-Sqlcmd -ServerInstance $TestInstance -Database $testDbName -Query $query -ErrorAction Stop
                      
            $stats.SuccessCount++
            Log-RestoreTest -SourceInstance $SourceInstance -TestInstance $TestInstance `
              -Database $dbName -BackupFile $backupFile.Name -BackupDate $backupDate `
              -Status "Success" -LogPath $LogPath
          }
        }
        catch {
          $stats.FailedCount++
          $errorMsg = $_.Exception.Message
          Log-RestoreTest -SourceInstance $SourceInstance -TestInstance $TestInstance `
            -Database $dbName -BackupFile $backupFile.Name -BackupDate $backupDate `
            -Status "Failed" -Error $errorMsg -LogPath $LogPath
          Write-Error "Failed to restore $dbName from $($backupFile.Name): $_"
        }
        finally {
          # Clean up test database
          try {
            if ($PSCmdlet.ShouldProcess($testDbName, "Remove test database")) {
              $null = Remove-SqlDatabase -ServerInstance $TestInstance -Database $testDbName -ErrorAction SilentlyContinue
            }
          }
          catch {
            Write-Warning ("Failed to clean up test database {0}:{1}" -f $testDbName, $_)
          }
        }
      }
    }
    catch {
      throw "Restore test process failed: $_"
    }
  }

  end {
    # Complete statistics
    $stats.EndTime = [DateTime]::Now
    $stats.Duration = $stats.EndTime - $stats.StartTime

    # Output summary
    Write-Output "`nRestore Test Completed:"
    Write-Output "  Source Instance:   $SourceInstance"
    Write-Output "  Test Instance:     $TestInstance"
    Write-Output "  Backups Tested:    $($stats.BackupsTested)"
    Write-Output "  Successful:        $($stats.SuccessCount)"
    Write-Output "  Failed:            $($stats.FailedCount)"
    Write-Output "  Start Time:        $($stats.StartTime)"
    Write-Output "  End Time:          $($stats.EndTime)"
    Write-Output "  Duration:          $($stats.Duration.ToString('hh\:mm\:ss'))"

    return $stats
  }
}

function Log-RestoreTest {
  param (
    [string]$SourceInstance,
    [string]$TestInstance,
    [string]$Database,
    [string]$BackupFile,
    [string]$BackupDate,
    [string]$Status,
    [string]$ErrorMessage,
    [string]$LogPath
  )

  if ($LogPath) {
    try {
      $logEntry = "$([DateTime]::Now),$SourceInstance,$TestInstance,$Database,$BackupFile,$BackupDate,$Status,$ErrorMessage"
      $logEntry | Out-File -FilePath $LogPath -Append
    }
    catch {
      Write-Warning "Failed to write to log file: $_"
    }
  }
}