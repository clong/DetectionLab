Write-Host "Configuring auditing policy GPOS..."
#Import-GPO -BackupGpoName 'Domain Controllers Enhanced Auditing Policy' -Path "c:\vagrant\resources\GPO\Domain_Controllers_Enhanced_Auditing_Policy" -TargetName 'Domain Controllers Enhanced Auditing Policy' -CreateIfNeeded
#New-GPLink -Name 'Domain Controllers Enhanced Auditing Policy' -Target "ou=Domain Controllers,dc=windomain,dc=local" -Enforced yes
