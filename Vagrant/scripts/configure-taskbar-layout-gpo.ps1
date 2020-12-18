# Purpose: Install the GPO that disables Windows Defender and AMSI
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Importing the GPO to set the Taskbar layout..."
Import-GPO -BackupGpoName 'Taskbar Layout' -Path "c:\vagrant\resources\GPO\taskbar_layout" -TargetName 'Taskbar Layout' -CreateIfNeeded

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Copying layout file to SYSVOL..."
Copy-Item "c:\vagrant\resources\GPO\taskbar_layout\DetectionLabLayout.xml" "c:\Windows\SYSVOL\domain\scripts\DetectionLabLayout.xml"

$OU = "ou=Domain Controllers,dc=windomain,dc=local"
$gPLinks = $null
$gPLinks = Get-ADOrganizationalUnit -Identity $OU -Properties name, distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name 'Taskbar Layout'
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path) {
    New-GPLink -Name 'Taskbar Layout' -Target $OU -Enforced yes
} Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Taskbar Layout GPO was already linked at $OU. Moving On."
}

$OU = "ou=Workstations,dc=windomain,dc=local"
$gPLinks = $null
$gPLinks = Get-ADOrganizationalUnit -Identity $OU -Properties name, distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name 'Taskbar Layout'
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path) {
    New-GPLink -Name 'Taskbar Layout' -Target $OU -Enforced yes
} Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Taskbar Layout GPO was already linked at $OU. Moving On."
}

$OU = "ou=Servers,dc=windomain,dc=local"
$gPLinks = $null
$gPLinks = Get-ADOrganizationalUnit -Identity $OU -Properties name, distinguishedName, gPLink, gPOptions
$GPO = Get-GPO -Name 'Taskbar Layout'
If ($gPLinks.LinkedGroupPolicyObjects -notcontains $gpo.path) {
    New-GPLink -Name 'Taskbar Layout' -Target $OU -Enforced yes
} Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Taskbar Layout GPO was already linked at $OU. Moving On."
}
gpupdate /force
