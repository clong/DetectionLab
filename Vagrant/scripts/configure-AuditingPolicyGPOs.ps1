# Purpose: Installs the GPOs for the custom WinEventLog auditing policy.
Write-Host "Configuring auditing policy GPOS..."
Write-Host "Importing Domain Controller Enhanced Auditing Policy..."
Import-GPO -BackupGpoName 'Domain Controllers Enhanced Auditing Policy' -Path "c:\vagrant\resources\GPO\Domain_Controllers_Enhanced_Auditing_Policy" -TargetName 'Domain Controllers Enhanced Auditing Policy' -CreateIfNeeded
New-GPLink -Name 'Domain Controllers Enhanced Auditing Policy' -Target "ou=Domain Controllers,dc=windomain,dc=local" -Enforced yes

Write-Host "Importing Servers Enhanced Auditing Policy..."
Import-GPO -BackupGpoName 'Servers Enhanced Auditing Policy' -Path "c:\vagrant\resources\GPO\Servers_Enhanced_Auditing_Policy" -TargetName 'Servers Enhanced Auditing Policy' -CreateIfNeeded
New-GPLink -Name 'Servers Enhanced Auditing Policy' -Target "ou=Servers,dc=windomain,dc=local" -Enforced yes

Write-Host "Importing Workstations Enhanced Auditing Policy..."
Import-GPO -BackupGpoName 'Workstations Enhanced Auditing Policy' -Path "c:\vagrant\resources\GPO\Workstations_Enhanced_Auditing_Policy" -TargetName 'Workstations Enhanced Auditing Policy' -CreateIfNeeded
New-GPLink -Name 'Workstations Enhanced Auditing Policy' -Target "ou=Workstations,dc=windomain,dc=local" -Enforced yes
