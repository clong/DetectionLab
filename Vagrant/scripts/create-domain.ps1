# Purpose: Creates the "windomain.local" domain
# Source: https://github.com/StefanScherer/adfs2
param ([String] $ip)

$subnet = $ip -replace "\.\d+$", ""

$domain= "windomain.local"

if ((gwmi win32_computersystem).partofdomain -eq $false) {

  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing RSAT tools"
  Import-Module ServerManager
  Add-WindowsFeature RSAT-AD-PowerShell,RSAT-AD-AdminCenter

  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating domain controller..."
  # Disable password complexity policy
  secedit /export /cfg C:\secpol.cfg
  (gc C:\secpol.cfg).replace("PasswordComplexity = 1", "PasswordComplexity = 0") | Out-File C:\secpol.cfg
  secedit /configure /db C:\Windows\security\local.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY
  rm -force C:\secpol.cfg -confirm:$false

  # Set administrator password
  $computerName = $env:COMPUTERNAME
  $adminPassword = "vagrant"
  $adminUser = [ADSI] "WinNT://$computerName/Administrator,User"
  $adminUser.SetPassword($adminPassword)

  $PlainPassword = "vagrant" # "P@ssw0rd"
  $SecurePassword = $PlainPassword | ConvertTo-SecureString -AsPlainText -Force

  # Windows Server 2016 R2
  Install-WindowsFeature AD-domain-services
  Import-Module ADDSDeployment
  Install-ADDSForest `
    -SafeModeAdministratorPassword $SecurePassword `
    -CreateDnsDelegation:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -DomainMode "7" `
    -DomainName $domain `
    -DomainNetbiosName "WINDOMAIN" `
    -ForestMode "7" `
    -InstallDns:$true `
    -LogPath "C:\Windows\NTDS" `
    -NoRebootOnCompletion:$true `
    -SysvolPath "C:\Windows\SYSVOL" `
    -Force:$true

  $newDNSServers = "127.0.0.1", "8.8.8.8", "4.4.4.4"

  $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -And ($_.IPAddress).StartsWith($subnet) }
  if ($adapters) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Setting DNS"
    # Don't do this in Azure. If the network adatper description contains "Hyper-V", this won't apply changes.
    $adapters | ForEach-Object {if (!($_.Description).Contains("Hyper-V")) {$_.SetDNSServerSearchOrder($newDNSServers)}}
  }
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Setting timezone to UTC"
  c:\windows\system32\tzutil.exe /s "UTC"

  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Excluding NAT interface from DNS"
  $nics=Get-WmiObject "Win32_NetworkAdapterConfiguration where IPEnabled='TRUE'" |? { $_.IPAddress[0] -ilike "172.25.*" }
  $dnslistenip=$nics.IPAddress
  $dnslistenip
  dnscmd /ResetListenAddresses  $dnslistenip

  $nics=Get-WmiObject "Win32_NetworkAdapterConfiguration where IPEnabled='TRUE'" |? { $_.IPAddress[0] -ilike "10.*" }
  foreach($nic in $nics)
  {
    $nic.DomainDNSRegistrationEnabled = $false
    $nic.SetDynamicDNSRegistration($false) |Out-Null
    }


 #Get-DnsServerResourceRecord -ZoneName $domain -type 1 -Name "@" |Select-Object HostName,RecordType -ExpandProperty RecordData |Where-Object {$_.IPv4Address -ilike "10.*"}|Remove-DnsServerResourceRecord
 $RRs= Get-DnsServerResourceRecord -ZoneName $domain -type 1 -Name "@"

 foreach($RR in $RRs)
 {
  if ( (Select-Object  -InputObject $RR HostName,RecordType -ExpandProperty RecordData).IPv4Address -ilike "10.*")
  {
   Remove-DnsServerResourceRecord -ZoneName $domain -RRType A -Name "@" -RecordData $RR.RecordData.IPv4Address -Confirm
  }

 }
  Restart-Service DNS

}
