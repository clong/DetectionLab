# Purpose: Installs the GPOs needed to specify a Windows Event Collector and makes certain event channels readable by Event Logger
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Importing the GPO to specify the WEF collector"
$GPOName = 'Windows Event Forwarding Server'
Import-GPO -BackupGpoName $GPOName -Path "c:\vagrant\resources\GPO\wef_configuration" -TargetName $GPOName -CreateIfNeeded
$gpLinks = $null
$OU = "OU=Servers,dc=windomain,dc=local"

$gPLinks = Get-ADOrganizationalUnit -Server "dc.windomain.local" -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name $GPOName
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name $GPOName -Target $OU -Enforced yes
} else {
    Write-Host "GpLink $GPOName already linked on $OU. Moving On."
}
$OU = "ou=Domain Controllers,dc=windomain,dc=local"
$gpLinks = $null
$gPLinks = Get-ADOrganizationalUnit -Server "dc.windomain.local" -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name $GPOName
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name $GPOName -Target $OU -Enforced yes
} else {
    Write-Host "GpLink $GPOName already linked on $OU. Moving On."
}
$OU = "ou=Workstations,dc=windomain,dc=local"
$gpLinks = $null
$gPLinks = Get-ADOrganizationalUnit -Server "dc.windomain.local" -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name $GPOName
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name $GPOName -Target $OU -Enforced yes
} else {
    Write-Host "GpLink $GPOName already linked on $OU. Moving On."
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Importing the GPO to modify ACLs on Custom Event Channels"

$GPOName = 'Custom Event Channel Permissions'
Import-GPO -BackupGpoName $GPOName -Path "c:\vagrant\resources\GPO\wef_configuration" -TargetName $GPOName -CreateIfNeeded
$gpLinks = $null
$OU = "OU=Servers,dc=windomain,dc=local"
$gPLinks = Get-ADOrganizationalUnit -Server "dc.windomain.local" -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name $GPOName
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name $GPOName -Target $OU -Enforced yes
}
else
{
    Write-Host "GpLink $GPOName already linked on $OU. Moving On."
}
$OU = "ou=Domain Controllers,dc=windomain,dc=local"
$gPLinks = Get-ADOrganizationalUnit -Server "dc.windomain.local" -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name $GPOName
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name $GPOName -Target $OU -Enforced yes
}
else
{
    Write-Host "GpLink $GPOName already linked on $OU. Moving On."
}
$OU = "ou=Workstations,dc=windomain,dc=local"
$gPLinks = Get-ADOrganizationalUnit -Server "dc.windomain.local" -Identity $OU -Properties name,distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name $GPOName
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path)
{
    New-GPLink -Name $GPOName -Target $OU -Enforced yes
}
else
{
    Write-Host "GpLink $GPOName already linked on $OU. Moving On."
}

gpupdate /force
