function Get-SubscriptionCompliance {
  [CmdletBinding()]
  param ()

  Write-Host "Connecting to Azure..." -ForegroundColor Cyan
  Connect-AzAccount | Out-Null
  $subscriptions = Get-AzSubscription

  $complianceResults = @()

  foreach ($sub in $subscriptions) {
      Write-Host "Checking Subscription: $($sub.Name)" -ForegroundColor Yellow
      Set-AzContext -SubscriptionId $sub.Id | Out-Null

      $resources = Get-AzResource
      foreach ($resource in $resources) {
          $compliance = [PSCustomObject]@{
              Subscription = $sub.Name
              ResourceName = $resource.Name
              ResourceType = $resource.ResourceType
              TagCompliant = (Test-TagCompliance -Resource $resource)
              NameCompliant = (Test-NamingCompliance -Resource $resource)
              SecurityCompliant = (Test-SecurityCompliance -Resource $resource)
          }
          $complianceResults += $compliance
      }
  }

  return $complianceResults
}