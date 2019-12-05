# Purpose: Sets up the Server and Workstations OUs

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Checking AD services status..."
$svcs = "adws","dns","kdc","netlogon"
Get-Service -name $svcs -ComputerName localhost | Select Machinename,Name,Status

# Hardcoding DC hostname in hosts file
Add-Content "c:\windows\system32\drivers\etc\hosts" "        192.168.38.102    dc.windomain.local"

# Force DNS resolution of the domain
ping /n 1 dc.windomain.local
ping /n 1 windomain.local

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating Server and Workstation OUs..."
# Create the Servers OU if it doesn't exist
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating Server OU"
try {
  Get-ADOrganizationalUnit -Identity 'OU=Servers,DC=windomain,DC=local' | Out-Null
  Write-Host "Servers OU already exists. Moving On."
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
  New-ADOrganizationalUnit -Name "Servers" -Server "dc.windomain.local"
}

# Create the Workstations OU if it doesn't exist
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating Workstations OU"
try {
  Get-ADOrganizationalUnit -Identity 'OU=Workstations,DC=windomain,DC=local' | Out-Null
  Write-Host "Workstations OU already exists. Moving On."
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
  New-ADOrganizationalUnit -Name "Workstations" -Server "dc.windomain.local"
}

# Sysprep breaks auto-login. Let's restore it here:
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value 1
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Value "vagrant"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Value "vagrant"
