$users = @{
  'abertram' = 'Adam Bertram'
  'bcarter'  = 'Bob Carter'
  'cdoe'     = 'Charlie Doe'
}

Write-Output "abertram's full name is $($users['abertram'])"