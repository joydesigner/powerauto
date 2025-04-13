# This script is part of the PowerAutoModule project.
# Get Sql Backup Report

function Get-SqlBackupReport {
  <#
  .SYNOPSIS
      Generates reports on backup and restore operations.
  
  .DESCRIPTION
      Creates detailed reports from backup and restore logs,
      with filtering and summary statistics.
  
  .PARAMETER LogPath
      Path to backup or restore log file.
  
  .PARAMETER Days
      Number of days to include in report (default: 7).
  
  .PARAMETER OutputFormat
      Report output format (Console, HTML, CSV).
  
  .PARAMETER OutputPath
      File path to save report (required for HTML/CSV).
  
  .EXAMPLE
      PS> Get-SqlBackupReport -LogPath "C:\Logs\sql_backup.log" -Days 30
  
  .EXAMPLE
      PS> Get-SqlBackupReport -LogPath "C:\Logs\sql_restore.log" -OutputFormat HTML -OutputPath "C:\Reports\restore_test.html"
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$LogPath,
      
    [Parameter()]
    [int]$Days = 7,
      
    [Parameter()]
    [ValidateSet("Console", "HTML", "CSV")]
    [string]$OutputFormat = "Console",
      
    [Parameter()]
    [string]$OutputPath
  )

  begin {
    # Validate log file exists
    if (-not (Test-Path $LogPath -PathType Leaf)) {
      throw "Log file not found: $LogPath"
    }

    # Calculate cutoff date
    $cutoffDate = (Get-Date).AddDays(-$Days)
  }

  process {
    try {
      # Import log data
      $logData = Import-Csv -Path $LogPath | 
      Where-Object { [DateTime]$_.Timestamp -ge $cutoffDate }

      if (-not $logData) {
        Write-Warning "No log entries found within the last $Days days"
        return
      }

      # Generate report based on output format
      switch ($OutputFormat) {
        "HTML" {
          if (-not $OutputPath) {
            throw "OutputPath is required for HTML reports"
          }

          $htmlReport = $logData | ConvertTo-Html -As Table -PreContent "<h1>SQL Backup Report</h1><p>Generated on $(Get-Date)</p>"
          $htmlReport | Out-File -FilePath $OutputPath -Force
          Write-Output "HTML report saved to $OutputPath"
        }
        "CSV" {
          if (-not $OutputPath) {
            throw "OutputPath is required for CSV reports"
          }

          $logData | Export-Csv -Path $OutputPath -NoTypeInformation -Force
          Write-Output "CSV report saved to $OutputPath"
        }
        default {
          # Console output
          Write-Output "`nSQL Backup/Restore Report"
          Write-Output "Generated: $(Get-Date)"
          Write-Output "Time Range: Last $Days days"
          Write-Output "Log File: $LogPath"
          Write-Output "`nSummary:"
                  
          $logData | Group-Object Status | ForEach-Object {
            Write-Output "  $($_.Name): $($_.Count)"
          }
                  
          Write-Output "`nDetailed Records:"
          $logData | Format-Table -AutoSize
        }
      }
    }
    catch {
      throw "Failed to generate report: $_"
    }
  }
}