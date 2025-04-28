function Test-TagCompliance {
  param (
      [Parameter(Mandatory)]
      $Resource
  )

  $requiredTags = @("Owner", "Environment", "CostCenter")
  foreach ($tag in $requiredTags) {
      if (-not $Resource.Tags.ContainsKey($tag)) {
          return $false
      }
  }
  return $true
}