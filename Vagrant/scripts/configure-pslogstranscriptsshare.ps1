# Purpose: Configure an SMB share for Powershell transcription logs to be written to
# Source: https://blogs.msdn.microsoft.com/powershell/2015/06/09/powershell-the-blue-team/
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Configuring the Powershell Transcripts Share"
If (-not (Test-Path c:\pslogs))
{
    md c:\pslogs
}


## Kill all inherited permissions
$acl = Get-Acl c:\pslogs
$acl.SetAccessRuleProtection($true, $false)


## Grant Administrators full control
$administrators = [System.Security.Principal.NTAccount] "Administrators"
$permission = $administrators,"FullControl","ObjectInherit,ContainerInherit","None","Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.AddAccessRule($accessRule)


## Grant everyone else Write and ReadAttributes. This prevents users from listing
## transcripts from other machines on the domain.
$everyone = [System.Security.Principal.NTAccount] "Everyone"
$permission = $everyone,"Write,ReadAttributes","ObjectInherit,ContainerInherit","None","Allow"
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.AddAccessRule($accessRule)

## TODO: Leaving this commented out so Splunk Forwader can read these files
## Might be a way to leave this permission intact but still allow Splunk
## Deny "Creator Owner" everything. This prevents users from
## viewing the content of previously written files.
#$creatorOwner = [System.Security.Principal.NTAccount] "Creator Owner"
#$permission = $creatorOwner,"FullControl","ObjectInherit,ContainerInherit","InheritOnly","Deny"
#$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
#$acl.AddAccessRule($accessRule)


## Set the ACL
$acl | Set-Acl c:\pslogs\


## Create the SMB Share, granting Everyone the right to read and write files. Specific
## actions will actually be enforced by the ACL on the file folder.
if ((Get-SmbShare -Name pslogs -ea silent) -eq $null)
{
    New-SmbShare -Name pslogs -Path c:\pslogs -ChangeAccess Everyone
}
