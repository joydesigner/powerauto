function Send-HealthAlert {
  <#
  .SYNOPSIS
      Sends health alert notifications.
  
  .DESCRIPTION
      Customizable function for sending various types of health alerts.
  
  .PARAMETER Message
      Alert message content.
  
  .PARAMETER Severity
      Alert severity level (Info, Warning, Critical).
  
  .PARAMETER ComputerName
      Affected server name.
  
  .PARAMETER AlertType
      Type of alert (Disk, CPU, Memory, Service).
  
  .EXAMPLE
      PS> Send-HealthAlert -Message "Disk space critical" -Severity Critical -ComputerName "Server01"
  #>
  [CmdletBinding()]
  param (
      [Parameter(Mandatory)]
      [string]$Message,
      
      [Parameter()]
      [ValidateSet("Info", "Warning", "Critical")]
      [string]$Severity = "Warning",
      
      [Parameter()]
      [string]$ComputerName,
      
      [Parameter()]
      [ValidateSet("Disk", "CPU", "Memory", "Service", "Other")]
      [string]$AlertType = "Other"
  )

  # Implementation would use the same email/SMS/webhook logic
  # as the main monitoring function, but broken out for reuse
}