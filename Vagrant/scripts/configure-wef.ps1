# Install the GPO that specifies the WEF collector
Write-Host "Importing the GPO to specify the WEF collector"
Import-GPO -BackupGpoName 'Windows Event Forwarding Server' -Path "c:\vagrant\resources" -TargetName 'Windows Event Forwarding Server' -CreateIfNeeded
New-GPLink -Name 'Windows Event Forwarding Server' -Target "dc=windomain,dc=local" -Enforced yes
New-GPLink -Name 'Windows Event Forwarding Server' -Target "ou=Domain Controllers,dc=windomain,dc=local" -Enforced yes
gpupdate /force
# Give the Network Service account read permission on the Security Event Log
Write-Host "Giving Network Service Acct read permission on the Security Event Log"
wevtutil set-log security /ca:'O:BAG:SYD:(A;;0xf0005;;;SY)(A;;0x5;;;BA)(A;;0x1;;;S-1-5-32-573)(A;;0x1;;;S-1-5-20)'
# Enable WinRM
Write-Host "Enabling WinRM"
winrm qc /q:true
Write-Host "Rebooting to make settings take effect..."
