# This script sets up the Server and Workstations OUs
Write-Host "Sleeping for 30 seconds, then creating Server and Workstation OUs"
Start-Sleep 30
New-ADOrganizationalUnit -Name "Servers" -Server "dc.windomain.local"
New-ADOrganizationalUnit -Name "Workstations" -Server "dc.windomain.local"

# Sysprep breaks auto-login. Let's restore it here:
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value 1
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Value "vagrant"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Value "vagrant"
