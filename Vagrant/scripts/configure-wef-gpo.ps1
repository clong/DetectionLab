# Purpose: Installs the GPOs needed to specify a Windows Event Collector and makes certain event channels readable by Event Logger
Write-Host "Importing the GPO to specify the WEF collector"
Import-GPO -BackupGpoName 'Windows Event Forwarding Server' -Path "c:\vagrant\resources\GPO\wef_configuration" -TargetName 'Windows Event Forwarding Server' -CreateIfNeeded
New-GPLink -Name 'Windows Event Forwarding Server' -Target "dc=windomain,dc=local" -Enforced yes
New-GPLink -Name 'Windows Event Forwarding Server' -Target "ou=Domain Controllers,dc=windomain,dc=local" -Enforced yes
Write-Host "Importing the GPO to modify ACLs on Custom Event Channels"
Import-GPO -BackupGPOName 'Custom Event Channel Permissions' -Path "c:\vagrant\resources\GPO\wef_configuration" -TargetName 'Custom Event Channel Permissions' -CreateIfNeeded
New-GPLink -Name 'Custom Event Channel Permissions' -Target "dc=windomain,dc=local" -Enforced yes
New-GPLink -Name 'Custom Event Channel Permissions' -Target "ou=Domain Controllers,dc=windomain,dc=local" -Enforced yes
New-GPLink -Name 'Custom Event Channel Permissions' -Target "ou=Servers,dc=windomain,dc=local" -Enforced yes
New-GPLink -Name 'Custom Event Channel Permissions' -Target "ou=Workstations,dc=windomain,dc=local" -Enforced yes
gpupdate /force
# Enable WinRM
Write-Host "Enabling WinRM"
winrm qc /q:true
Write-Host "Rebooting to make settings take effect..."
