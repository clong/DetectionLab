Import-Module ActiveDirectory
Try {
  NEW-ADOrganizationalUnit -name "IT-Services"
} Catch {}
Try {
  NEW-ADOrganizationalUnit -name "ServiceAccounts" -path "OU=IT-Services,DC=windomain,DC=local"
} Catch {}

$identity = "jb7ep"
$hostname = "EP"
$password = 'MyPa$sw0rd'

Try {
  Remove-ADUser -Identity $identity -Confirm:$false
} Catch {}

New-ADUser -SamAccountName $identity -GivenName "JBoss7 SSO" -Surname "JBoss7 SSO" -Name $identity `
  -CannotChangePassword $true -PasswordNeverExpires $true -Enabled $true `
  -Path "OU=ServiceAccounts,OU=IT-Services,DC=windomain,DC=local" `
  -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force)

# http://www.jeffgeiger.com/wiki/index.php/PowerShell/ADUnixImport
Get-ADUser -Identity $identity | Set-ADAccountControl -DoesNotRequirePreAuth:$true

# create keytab

New-Item -Path c:\vagrant\resources -type directory -Force -ErrorAction SilentlyContinue
If (Test-Path c:\vagrant\resources\$identity.keytab) {
  Remove-Item c:\vagrant\resources\$identity.keytab
}

$servicePrincipalName = 'HTTP/' + $hostname + '.windomain.local@WINDOMAIN.LOCAL'
& ktpass -out c:\vagrant\resources\$identity.keytab -princ $servicePrincipalName -mapUser "WINDOMAIN\$identity" -mapOp set -pass $password  -crypto RC4-HMAC-NT

If (Test-Path c:\vagrant\resources\$identity.keytab) {
  Write-Host -fore green "Keytab created for user $identity at c:\vagrant\resources\$identity.keytab"

  & setspn -l $identity
} else {
  Write-Host -fore red "Keytab not created"
}

