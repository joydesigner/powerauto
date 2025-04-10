#region users hash table
$users = @{
  'abertram' = 'Adam Bertram'
  'bcarter'  = 'Bob Carter'
  'cdoe'     = 'Charlie Doe'
}
#endregion

Write-Output "abertram's full name is $($users['abertram'])"