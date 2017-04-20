# Install the GPO that specifies the WEF collector
Write-Host "Importing the GPO to enable Powershell Module, ScriptBlock and Transcript logging..."
Import-GPO -BackupGpoName 'Powershell Logging' -Path "c:\vagrant\resources\GPO\powershell_logging" -TargetName 'Powershell Logging' -CreateIfNeeded
New-GPLink -Name 'Powershell Logging' -Target "dc=windomain,dc=local" -Enforced yes
New-GPLink -Name 'Powershell Logging' -Target "ou=Domain Controllers,dc=windomain,dc=local" -Enforced yes
gpupdate /force
