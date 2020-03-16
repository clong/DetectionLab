# Purpose: Joins a Windows host to the deathstar.local domain which was created with "create-domain.ps1".
# Source: https://github.com/StefanScherer/adfs2

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Joining the domain..."

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) First, set DNS to DC to join the domain..."
$newDNSServers = "10.1.1.102"
$adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPAddress -match "192.168.38."}
$adapters | ForEach-Object {$_.SetDNSServerSearchOrder($newDNSServers)}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Now join the domain..."
$hostname = $(hostname)
$user = "deathstar.local\vagrant"
$pass = ConvertTo-SecureString "vagrant" -AsPlainText -Force
$DomainCred = New-Object System.Management.Automation.PSCredential $user, $pass

# Place the computer in the correct OU based on hostname
If ($hostname -eq "wef") {
  Add-Computer -DomainName "deathstar.local" -credential $DomainCred -OUPath "ou=Servers,dc=deathstar,dc=local" -PassThru
} ElseIf ($hostname -eq "win10") {
  Write-Host "Adding Win10 to the domain. Sometimes this step times out. If that happens, just run 'vagrant reload win10 --provision'" #debug
  Add-Computer -DomainName "deathstar.local" -credential $DomainCred -OUPath "ou=Workstations,dc=deathstar,dc=local"
} Else {
  Add-Computer -DomainName "deathstar.local" -credential $DomainCred -PassThru
}

Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Value 1
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultUserName -Value "vagrant"
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name DefaultPassword -Value "vagrant"

# Stop Windows Update
Write-Host "Disabling Windows Updates and Windows Module Services"
Set-Service wuauserv -StartupType Disabled
Stop-Service wuauserv
Set-Service TrustedInstaller -StartupType Disabled
Stop-Service TrustedInstaller
