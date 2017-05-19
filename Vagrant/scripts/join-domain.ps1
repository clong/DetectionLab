Write-Host 'Join the domain'

Start-Sleep -m 2000

Write-Host "First, set DNS to DC to join the domain"
$newDNSServers = "192.168.38.2"
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPAddress -match "192.168.38."}
$adapters | ForEach-Object {$_.SetDNSServerSearchOrder($newDNSServers)}

Start-Sleep -m 2000

Write-Host "Now join the domain"
$hostname = $(hostname)
$user = "windomain.local\vagrant"
$pass = ConvertTo-SecureString "vagrant" -AsPlainText -Force
$DomainCred = New-Object System.Management.Automation.PSCredential $user, $pass

# Place the computer in the correct OU based on hostname
If ($hostname -eq "wef") {
  Add-Computer -DomainName "windomain.local" -credential $DomainCred -OUPath "ou=Servers,dc=windomain,dc=local" -PassThru
} ElseIf ($hostname -eq "win10") {
  Add-Computer -DomainName "windomain.local" -credential $DomainCred -OUPath "ou=Workstations,dc=windomain,dc=local" -PassThru
} Else {
  Add-Computer -DomainName "windomain.local" -credential $DomainCred -PassThru
}

Write-Host "Setting timezone to UTC"
c:\windows\system32\tzutil.exe /s "UTC"

Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value 1
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Value "vagrant"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Value "vagrant"
###  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultDomainName -Value "WINDOMAIN"
