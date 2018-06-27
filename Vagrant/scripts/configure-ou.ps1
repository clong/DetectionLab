# Purpose: Sets up the Server and Workstations OUs
Write-Host "Creating Server and Workstation OUs..."
Write-Host "Creating Servers OU..."
if (!([ADSI]::Exists("LDAP://OU=Servers,DC=windomain,DC=local")))
{
    New-ADOrganizationalUnit -Name "Servers" -Server "dc.windomain.local"
}
else
{
    Write-Host "Servers OU already exists. Moving On."
}
Write-Host "Creating Workstations OU"
if (!([ADSI]::Exists("LDAP://OU=Workstations,DC=windomain,DC=local")))
{
    New-ADOrganizationalUnit -Name "Workstations" -Server "dc.windomain.local"
}
else
{
    Write-Host "Workstations OU already exists. Moving On."
}
# Sysprep breaks auto-login. Let's restore it here:
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value 1
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Value "vagrant"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Value "vagrant"
