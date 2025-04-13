function Invoke-ServerHealthCheck {
  <#
  .SYNOPSIS
      Performs comprehensive health checks on servers and sends alerts.
  
  .DESCRIPTION
      Monitors disk space, CPU usage, memory, and critical services across multiple servers.
      Can automatically restart failed services and send email alerts.
  
  .PARAMETER ComputerNames
      Array of server names to monitor.
  
  .PARAMETER DiskThresholdGB
      Free space threshold in GB to trigger alerts.
  
  .PARAMETER CpuThresholdPercent
      CPU usage percentage threshold to trigger alerts.
  
  .PARAMETER MemoryThresholdPercent
      Memory usage percentage threshold to trigger alerts.
  
  .PARAMETER ServicesToMonitor
      Array of service names to check.
  
  .PARAMETER SmtpServer
      SMTP server for sending alerts.
  
  .PARAMETER AlertRecipients
      Email addresses to receive alerts.
  
  .PARAMETER FromAddress
      Sender email address for alerts.
  
  .PARAMETER AutoRestartServices
      Switch to enable automatic restart of failed services.
  
  .PARAMETER WhatIf
      Shows what would happen without actually making changes.
  
  .EXAMPLE
      PS> Invoke-ServerHealthCheck -ComputerNames "Server01","Server02" -DiskThresholdGB 20
  
  .EXAMPLE
      PS> Invoke-ServerHealthCheck -ComputerNames (Get-Content "servers.txt") -AutoRestartServices -WhatIf
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
      [Parameter(Mandatory)]
      [string[]]$ComputerNames,
      
      [Parameter()]
      [int]$DiskThresholdGB = 10,
      
      [Parameter()]
      [int]$CpuThresholdPercent = 90,
      
      [Parameter()]
      [int]$MemoryThresholdPercent = 90,
      
      [Parameter()]
      [string[]]$ServicesToMonitor = @("Spooler", "WinRM", "EventLog"),
      
      [Parameter()]
      [string]$SmtpServer = "smtp.company.com",
      
      [Parameter()]
      [string[]]$AlertRecipients = @("admin@company.com"),
      
      [Parameter()]
      [string]$FromAddress = "alerts@company.com",
      
      [Parameter()]
      [switch]$AutoRestartServices
  )

  begin {
      $results = @()
      $alerts = @()
      $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  }

  process {
      foreach ($computer in $ComputerNames) {
          try {
              # Test connection first
              if (-not (Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction Stop)) {
                  $alertMsg = "Server $computer is not responding to ping"
                  $alerts += $alertMsg
                  Write-Warning $alertMsg
                  continue
              }

              # Initialize server health object
              $serverHealth = [PSCustomObject]@{
                  ComputerName = $computer
                  Timestamp    = $timestamp
                  DiskStatus   = @()
                  CpuStatus    = $null
                  MemoryStatus = $null
                  ServiceStatus = @()
                  IsHealthy    = $true
              }

              # Check disk space
              $disks = Get-CimInstance -ComputerName $computer -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
              foreach ($disk in $disks) {
                  $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
                  $totalGB = [math]::Round($disk.Size / 1GB, 2)
                  $percentFree = [math]::Round(($freeGB / $totalGB) * 100, 2)
                  
                  $diskStatus = [PSCustomObject]@{
                      Drive       = $disk.DeviceID
                      FreeGB      = $freeGB
                      TotalGB     = $totalGB
                      PercentFree = $percentFree
                      IsCritical  = $freeGB -lt $DiskThresholdGB
                  }
                  
                  $serverHealth.DiskStatus += $diskStatus
                  
                  if ($diskStatus.IsCritical) {
                      $alertMsg = "Low disk space on $computer - Drive $($disk.DeviceID) has only $freeGB GB free ($percentFree%)"
                      $alerts += $alertMsg
                      $serverHealth.IsHealthy = $false
                  }
              }

              # Check CPU usage
              $cpu = Get-CimInstance -ComputerName $computer -ClassName Win32_Processor -ErrorAction Stop | 
                     Measure-Object -Property LoadPercentage -Average | 
                     Select-Object -ExpandProperty Average
              
              $serverHealth.CpuStatus = [PSCustomObject]@{
                  UsagePercent = $cpu
                  IsCritical   = $cpu -gt $CpuThresholdPercent
              }
              
              if ($serverHealth.CpuStatus.IsCritical) {
                  $alertMsg = "High CPU usage on $computer - $cpu% (Threshold: $CpuThresholdPercent%)"
                  $alerts += $alertMsg
                  $serverHealth.IsHealthy = $false
              }

              # Check memory usage
              $os = Get-CimInstance -ComputerName $computer -ClassName Win32_OperatingSystem -ErrorAction Stop
              $usedMem = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB
              $totalMem = $os.TotalVisibleMemorySize / 1MB
              $memPercent = [math]::Round(($usedMem / $totalMem) * 100, 2)
              
              $serverHealth.MemoryStatus = [PSCustomObject]@{
                  UsedGB       = [math]::Round($usedMem, 2)
                  TotalGB      = [math]::Round($totalMem, 2)
                  UsagePercent = $memPercent
                  IsCritical   = $memPercent -gt $MemoryThresholdPercent
              }
              
              if ($serverHealth.MemoryStatus.IsCritical) {
                  $alertMsg = "High memory usage on $computer - $memPercent% (Threshold: $MemoryThresholdPercent%)"
                  $alerts += $alertMsg
                  $serverHealth.IsHealthy = $false
              }

              # Check services
              foreach ($serviceName in $ServicesToMonitor) {
                  try {
                      $service = Get-Service -ComputerName $computer -Name $serviceName -ErrorAction Stop
                      
                      $serviceStatus = [PSCustomObject]@{
                          Name      = $serviceName
                          Status    = $service.Status
                          IsRunning = $service.Status -eq "Running"
                      }
                      
                      $serverHealth.ServiceStatus += $serviceStatus
                      
                      if (-not $serviceStatus.IsRunning) {
                          $alertMsg = "Service $serviceName is not running on $computer"
                          $alerts += $alertMsg
                          $serverHealth.IsHealthy = $false
                          
                          if ($AutoRestartServices -and $PSCmdlet.ShouldProcess($computer, "Restart service $serviceName")) {
                              try {
                                  Restart-Service -InputObject $service -Force -ErrorAction Stop
                                  $serviceStatus.Status = "Restarted"
                                  $alertMsg += " - SERVICE RESTARTED"
                              }
                              catch {
                                  $alertMsg += " - FAILED TO RESTART: $_"
                                  Write-Error $_
                              }
                          }
                      }
                  }
                  catch {
                      $alertMsg = "Could not check service $serviceName on $computer : $_"
                      $alerts += $alertMsg
                      Write-Error $_
                  }
              }

              $results += $serverHealth
          }
          catch {
              $errorMsg = "Error checking $computer : $_"
              $alerts += $errorMsg
              Write-Error $errorMsg
          }
      }
  }

  end {
      # Send alerts if any
      if ($alerts.Count -gt 0) {
          $subject = "Server Health Alert - $timestamp"
          $body = $alerts -join "`r`n`r`n"
          
          if ($PSCmdlet.ShouldProcess($AlertRecipients -join ",", "Send health alerts")) {
              try {
                  Send-MailMessage -To $AlertRecipients -From $FromAddress `
                                  -Subject $subject -Body $body `
                                  -SmtpServer $SmtpServer -Priority High
              }
              catch {
                  Write-Error "Failed to send alert email: $_"
              }
          }
          else {
              Write-Output "[WhatIf] Would send alert email:"
              Write-Output "To: $($AlertRecipients -join ', ')"
              Write-Output "Subject: $subject"
              Write-Output "Body:`n$body"
          }
      }

      # Return results
      $results
  }
}