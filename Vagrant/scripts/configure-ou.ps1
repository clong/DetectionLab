# Purpose: Sets up the Server and Workstations OUs

# Hardcoding DC hostname in hosts file to sidestep any DNS issues
Add-Content "c:\windows\system32\drivers\etc\hosts" "        192.168.56.102    dc.windomain.local"

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating Server and Workstation OUs..."
# Create the Servers OU if it doesn't exist
$servers_ou_created = 0
while ($servers_ou_created -ne 1) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating Server OU..."
  try {
    Get-ADOrganizationalUnit -Identity 'OU=Servers,DC=windomain,DC=local' | Out-Null
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Servers OU already exists. Moving On."
    $servers_ou_created = 1
  }
  catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    New-ADOrganizationalUnit -Name "Servers" -Server "dc.windomain.local"
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Created Servers OU."
    $servers_ou_created = 1
  }
  catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Unable to reach Active Directory. Sleeping for 5 and trying again..."
    Start-Sleep 5
  }
  catch {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Something went wrong attempting to reach AD or create the OU."
  }
}

# Create the Workstations OU if it doesn't exist
$workstations_ou_created = 0
while ($workstations_ou_created -ne 1) {
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating Workstations OU..."
  try {
    Get-ADOrganizationalUnit -Identity 'OU=Workstations,DC=windomain,DC=local' | Out-Null
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Workstations OU already exists. Moving On."
    $workstations_ou_created = 1
  }
  catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    New-ADOrganizationalUnit -Name "Workstations" -Server "dc.windomain.local"
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Created Workstations OU."
    $workstations_ou_created = 1
  }
  catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Unable to reach Active Directory. Sleeping for 5 and trying again..."
    Start-Sleep 5
  }
  catch {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Something went wrong attempting to reach AD or create the OU."
  }
}
