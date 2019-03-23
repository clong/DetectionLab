# Purpose: Sets up the Server and Workstations OUs
Write-Host "Checking DNS Settings before starting..."
Get-DnsClientServerAddress | Select-Object –ExpandProperty ServerAddresses
Write-Host "Hardcoding windomain.local as localhost via the hosts file"
echo -e "\n127.0.0.1       windomain.local" >> /etc/hosts
Write-Host "Checking AD services status..."
$svcs = "adws","dns","kdc","netlogon"
Get-Service -name $svcs -ComputerName localhost | Select Machinename,Name,Status
Write-Host "Creating Server and Workstation OUs..."
Write-Host "Creating Servers OU..."
Write-Host "DEBUG: $env:computername.$env:userdnsdomain"
try {
  if (!([ADSI]::Exists("LDAP://OU=Servers,DC=windomain,DC=local")))
  {
    New-ADOrganizationalUnit -Name "Servers" -Server "dc.windomain.local"   
  }
  else
  {
      Write-Host "Servers OU already exists. Moving On."
  }
} catch {
  New-ADOrganizationalUnit -Name "Servers" -Server "dc.windomain.local"
}

Write-Host "Creating Workstations OU"
try {
  if (!([ADSI]::Exists("LDAP://OU=Workstations,DC=windomain,DC=local")))
  {
    New-ADOrganizationalUnit -Name "Workstations" -Server "dc.windomain.local"
  }
  else
  {
    Write-Host "Workstations OU already exists. Moving On."
  }
} catch { 
  New-ADOrganizationalUnit -Name "Workstations" -Server "dc.windomain.local"
}

# Sysprep breaks auto-login. Let's restore it here:
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value 1
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Value "vagrant"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Value "vagrant"
