@{
  ModuleVersion      = '1.0.0'
  RooTModule         = 'PowerAutoModule.psm1'
  FunctionToExport   = @(
    'Deploy-VMs',
    'Remove-ACRImages',
    'Import-NewHires',
    'Set-NewHirePassword',
    'Invoke-ServerHealthCheck',
    'Send-HealthAlert',
  )
  Author             = 'Xin Zheng'
  CompanyName        = 'Xin Zheng'
  Copyright          = '(c) 2025. All rights reserved.'
  Description        = 'PowerAutoModule includes a set of PowerShell functions for automatioin and deployment of Azure resources.'
  PowerShellVersion  = '7.0'
  RequiredModules    = @()
  RequiredAssemblies = @()
}