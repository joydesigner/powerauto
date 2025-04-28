
# Power Auto Module Scripts
This repository contains PowerShell scripts for automating various DevOps tasks, particularly focused on Azure resources.

#### Author
This repository is maintained by **Jason Zheng**, a versatile software, Cloud/DevOps engineer with expertise in automation scripting. For any questions, suggestions, or contributions, feel free to reach out via GitHub or email.

- GitHub: [Jason's Profile](https://github.com/joydesigner)

## Modular Design Approach
This repository follows a modular design approach, where each script is encapsulated as a reusable module. This allows for better maintainability, scalability, and reusability across different projects. By importing the `PowerAutoModule`, you can leverage the functionality of these scripts in your own automation workflows without modifying the core logic.

## Script Folder
The `PowerAutoModule/public` folder contains the PowerShell module scripts. Each script is designed to perform a specific task, such as creating Azure resources, managing Azure AD users, or performing health checks on servers.

### Benefits of Modular Design:
- **Reusability**: Scripts can be reused across multiple projects or scenarios.
- **Maintainability**: Updates to the module automatically propagate to all dependent scripts.
- **Scalability**: Easily extend the module with new functionality without disrupting existing workflows.
- **Consistency**: Ensures uniformity in automation tasks across teams and environments.

## Scripts Overview
1. **ACR Image Remove Script (`Remove_ACRImages.ps1`):**
2. **Automated Azure VM Deployment & Configuration (`Deploy_VMs.ps1`):**
3. **Import new users from CSV to Azure AD. (`Import-NewHires.ps1`):**
4. **Reset password using CSV input. (`Set-NewHiresPassword.ps1`):**
5. **Performs comprehensive health checks on servers. (`Invoke-ServerHealthCheck.ps1`):**
6. **Send Servers alerts. (`Send-HealthAlert.ps1`):**

### ACR Image Remove Script (`Remove_ACRImages.ps1`)

This script automates the process of cleaning up old Docker images from an Azure Container Registry (ACR).

#### Features:
- Removes old images from specified ACR
- Can target a specific repository or all repositories in the registry

#### Usage:
```powershell
# Import the module
Import-Module ./PowerAutoModule

# Basic usage (dry run)
Remove-ACRImages -RegistryName "myregistry" -ImagesToKeep 5 -WhatIf

# Actual deletion
Remove-ACRImages -RegistryName "myregistry" -ImagesToKeep 5

# Clean specific repository
Remove-ACRImages -RegistryName "myregistry" -Repository "myapp" -ImagesToKeep 3

# With subscription specification
Remove-ACRImages -RegistryName "myregistry" -SubscriptionName "My Subscription" -ImagesToKeep 10

```

### Automated Azure VM Deployment & Configuration (`Deploy_VMs.ps1`)
Manually deploying and configuring virtual machines in Azure is time-consuming and prone to human error. Here is my code to PowerShell to automate VM creation, apply security policies, and install software.
#### Usage:
```powershell
# Import the module
Import-Module ./PowerAutoModule

# Deploy servers with all parameters
$params = @{
    ResourceGroupName   = "ProdRG"
    Location           = "EastUS"
    VmNames            = "WebServer01", "WebServer02", "WebServer03", "WebServer04", "WebServer05"
    VirtualNetworkName = "ProdVNet"
    SubnetName         = "Web"
    SecurityGroupName  = "WebSG"
    CustomScriptUri    = "https://example.com/install-app.ps1"
    CustomScriptCommand = "powershell.exe -ExecutionPolicy Bypass -File install-app.ps1"
}

Deploy-WebServers @params

# Or with minimal parameters
Deploy-WebServers -ResourceGroupName "ProdRG" -Location "EastUS" -VmNames @("WebServer01","WebServer02") `
                  -VirtualNetworkName "ProdVNet" -SubnetName "Web" -SecurityGroupName "WebSG"
```

### Import new users from CSV to Azure AD. (`Import-NewHires.ps1`)

Example CSV:
```csv
SamAccountName,Name,GivenName,Surname,EmployeeID,JobTitle
jdoe,John Doe,John,Doe,10045,Accountant
bsmith,Bob Smith,Bob,Smith,10046,Financial Analyst
```
#### Usage:
```powershell
# Import module
Import-Module .\PowerAutoModule

# Basic usage
Import-NewHires -CsvPath "C:\HR\NewHires.csv"

# Advanced usage
Import-NewHires -CsvPath "C:\HR\NewHires.csv" `
                -Groups "FinanceDept","AllEmployees","MelbourneOffice" `
                -DefaultPassword "P@ssw0rd123!" `
                -Domain "ourcompany.com" `
                -OU "OU=Finance,DC=ourcompany,DC=com"

# WhatIf mode (test run)
Import-NewHires -CsvPath "C:\HR\NewHires.csv" -WhatIf
```

To use the module, simply import it into your PowerShell session or script:
```powershell
Import-Module ./PowerAutoModule
```

### Reset password using CSV input. (`Set-NewHiresPassword.ps1`)
Example CSV:
```csv
SamAccountName,Name,GivenName,Surname,EmployeeID,JobTitle
jdoe,John Doe,John,Doe,10045,Accountant
bsmith,Bob Smith,Bob,Smith,10046,Financial Analyst
```
#### Usage:
```powershell
# Import module
Import-Module.\PowerAutoModule
# Force password reset
Get-Content "C:\HR\NewHires.csv" | Import-Csv | 
    Select-Object -ExpandProperty SamAccountName |
    Set-NewHirePassword
```

### Performs comprehensive health checks on servers. (`Invoke-ServerHealthCheck.ps1`)
#### Usage:
```powershell
# Import module
Import-Module.\PowerAutoModule
# Basic monitoring
Invoke-ServerHealthCheck -ComputerNames "Server01","Server02"

# Advanced monitoring with custom thresholds
Invoke-ServerHealthCheck -ComputerNames (Get-Content "servers.txt") `
                         -DiskThresholdGB 20 `
                         -CpuThresholdPercent 85 `
                         -MemoryThresholdPercent 85 `
                         -ServicesToMonitor "Spooler","WinRM","EventLog","MSSQLSERVER" `
                         -AutoRestartServices

# WhatIf mode (test run)
Invoke-ServerHealthCheck -ComputerNames "Server01" -WhatIf

# Scheduled task integration (run daily)
$trigger = New-JobTrigger -Daily -At "3:00 AM"
Register-ScheduledJob -Name "DailyHealthCheck" -ScriptBlock {
    Import-Module ServerHealthMonitor
    Invoke-ServerHealthCheck -ComputerNames (Get-Content "C:\ServerList.txt")
} -Trigger $trigger
```

### Send Servers alerts. (`Send-HealthAlert.ps1`)  
#### Usage:

**Email Alert:** 
```powershell
Send-HealthAlert -Message "Disk space below 10GB on C:" -Severity Warning -ComputerName "SRV-WEB01" -AlertType Disk
```
**Multiple Channels**
```powershell
$teamsUrl = "https://outlook.office.com/webhook/..."
$slackUrl = "https://hooks.slack.com/..."

Send-HealthAlert -Message "Database service stopped" -Severity Critical `
                -ComputerName "SRV-DB01" -AlertType Service `
                -NotificationMethod All `
                -EmailRecipients "admin@company.com","dba@company.com" `
                -TeamsWebhookUrl $teamsUrl `
                -SlackWebhookUrl $slackUrl
```
**Integrated with Monitoring**
```powershell
# Check services and pipe failures to alert function
Get-Service -ComputerName "SRV-WEB01" -Name "W3SVC","MSSQLSERVER" | 
    Where-Object { $_.Status -ne "Running" } | 
    ForEach-Object {
        Send-HealthAlert -Message "$($_.DisplayName) service stopped" `
                        -Severity Critical `
                        -ComputerName $_.MachineName `
                        -AlertType Service `
                        -NotificationMethod All
    }
```
**Disk Space Monitoring**
```powershell
Disk Space Monitoring Integration$disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3 AND DeviceID='C:'"
if ($disk.FreeSpace / 1GB -lt 20) {
    Send-HealthAlert -Message "Drive C: has only $([math]::Round($disk.FreeSpace/1GB,2))GB free" `
                    -Severity Warning `
                    -AlertType Disk `
                    -NotificationMethod Email,Teams
}
```
**Scheduled Health Check**
```powershell
# In a scheduled task script
$cpu = Get-CimInstance -ClassName Win32_Processor | 
       Measure-Object -Property LoadPercentage -Average | 
       Select-Object -ExpandProperty Average

if ($cpu -gt 90) {
    Send-HealthAlert -Message "CPU at ${cpu}% for 15 minutes" `
                    -Severity Critical `
                    -AlertType CPU `
                    -NotificationMethod All
}
```
### File Archiving Module (`Start-FileArchiving.ps1`)
This script is designed to automate the process of archiving files from a source directory to a destination directory. It uses the `Copy-Item` cmdlet to copy the files, and the `Remove-Item` cmdlet to delete the original files after they have been copied.

#### Usage:
```powershell
# Import the module
Import-Module.\PowerAutoModule

# Basic usage
Start-FileArchiveProcess -SourcePath "\\fileserver\shared" -ArchivePath "\\fileserver\archive" -DaysOld 90

# Advanced archiving with compression
Start-FileArchiveProcess -SourcePath "C:\Projects" -ArchivePath "D:\Archives" `
                        -DaysOld 180 -CompressArchives -LogPath "C:\Logs\archive_$(Get-Date -Format yyyyMMdd).csv"

# Scheduled task integration
# Create scheduled task for weekly archiving
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"Import-Module PowerAutoModule; Start-FileArchiveProcess -SourcePath '\\fileserver\shared' -ArchivePath '\\fileserver\archive' -DaysOld 90 -RemoveDuplicates -LogPath 'C:\Logs\archive.log'`""

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am
Register-ScheduledTask -TaskName "Weekly File Archiving" -Action $action -Trigger $trigger -RunLevel Highest                        
```

### Clean Duplicated Files Module (`Start-DuplicateFileCleanup.ps1`)
This script is designed to automate the process of identifying and removing duplicate files from a specified directory. It uses the `Get-ChildItem` cmdlet to list all files in the directory, and the `Group-Object` cmdlet to group files by their content. It then selects the first file in each group and removes the rest.

#### Usage:
```powershell
# Import the module
Import-Module.\PowerAutoModule

# Duplicate removal only
Remove-DuplicateFiles -Path "\\fileserver\departments\marketing" -Algorithm SHA256 -WhatIf
```

### SQL Server database backup operations. (`Start-SqlBackup.ps1`)
This script is designed to automate the process of backing up SQL Server databases. It uses the `Invoke-Sqlcmd` cmdlet to execute SQL commands to create and restore backups.

#### Usage:
```powershell
# Import the module
Import-Module.\PowerAutoModule
# Daily Backups
Start-SqlBackupJob -SqlInstance "SQLProd01" -BackupPath "\\backupserver\SQLBackups" -LogPath "C:\Logs\sql_backup_$(Get-Date -Format yyyyMMdd).log"

#Scheduled Task Integration
# Daily backup task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"Import-Module SqlBackupRecovery; Start-SqlBackupJob -SqlInstance 'SQLProd01' -BackupPath 'D:\SQLBackups' -LogPath 'C:\Logs\sql_backup.log'`""

$trigger = New-ScheduledTaskTrigger -Daily -At 1am
Register-ScheduledTask -TaskName "Daily SQL Backups" -Action $action -Trigger $trigger -RunLevel Highest
```


### SQL Server database restore operations. (`Start-SqlRestore.ps1`)
This script is designed to automate the process of restoring SQL Server databases. It uses the `Invoke-Sqlcmd` cmdlet to execute SQL commands to create and restore backups.

#### Usage:
```powershell
Weekly Restore Tests
Test-SqlRestore -SourceInstance "SQLProd01" -TestInstance "SQLTest01" -BackupPath "\\backupserver\SQLBackups" -LatestOnly -LogPath "C:\Logs\sql_restore_$(Get-Date -Format yyyyMMdd).log"

# Scheduled Task Integration
# Weekly restore task
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"Import-Module SqlBackupRecovery; Test-SqlRestore -SourceInstance 'SQLProd01' -TestInstance 'SQLTest01' -BackupPath 'D:\SQLBackups' -LatestOnly -LogPath 'C:\Logs\sql_restore.log'`""

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3am
Register-ScheduledTask -TaskName "Weekly Restore Tests" -Action $action -Trigger $trigger -RunLevel Highest
```

### Generates reports on backup and restore operations. (`Start-SqlBackupReport.ps1`)
This module is designed to automate the process of generating SQL Server database backup and restore reports. It uses the `Invoke-Sqlcmd` cmdlet to execute SQL commands to retrieve backup & restore information and then generates a report.

#### Usage:
```powershell 
# Import the module
Import-Module.\PowerAutoModule
# Generate HTML Report
Get-SqlBackupReport -LogPath "C:\Logs\sql_backup.log" -Days 30 -OutputFormat HTML -OutputPath "C:\Reports\backup_report.html"
```

### Test Compliance
This module is designed to Scan all Azure Subscriptions you have access to.
- Check for:
  - Tag Compliance (mandatory tags like Owner, Environment, CostCenter).
  - Naming Convention Compliance (e.g., Resource Groups must start with rg-, VMs must start with vm-).
  - Security Settings Compliance (e.g., Storage Accounts must have secure transfer enabled).

#### Usage:
```powershell
Get-SubscriptionCompliance | Export-Csv -Path .\ComplianceReport.csv -NoTypeInformation
```
