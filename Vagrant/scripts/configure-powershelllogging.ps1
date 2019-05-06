# Purpose: Install the GPO that specifies the WEF collector
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Importing the GPO to enable Powershell Module, ScriptBlock and Transcript logging..."
Import-GPO -BackupGpoName 'Powershell Logging' -Path "c:\vagrant\resources\GPO\powershell_logging" -TargetName 'Powershell Logging' -CreateIfNeeded
$OU = "ou=Workstations,dc=windomain,dc=local"
$gPLinks = $null
$gPLinks = Get-ADOrganizationalUnit -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name 'Powershell Logging'
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name 'Powershell Logging' -Target $OU -Enforced yes
}
else
{
    Write-Host "Powershell Logging was already linked at $OU. Moving On."
}
$OU = "ou=Servers,dc=windomain,dc=local"
$gPLinks = $null
$gPLinks = Get-ADOrganizationalUnit -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name 'Powershell Logging'
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name 'Powershell Logging' -Target $OU -Enforced yes
}
else
{
    Write-Host "Powershell Logging was already linked at $OU. Moving On."
}
$OU = "ou=Domain Controllers,dc=windomain,dc=local"
$gPLinks = $null
$gPLinks = Get-ADOrganizationalUnit -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name 'Powershell Logging' -Target $OU -Enforced yes
}
else
{
    Write-Host "Powershell Logging was already linked at $OU. Moving On."
}
gpupdate /force
