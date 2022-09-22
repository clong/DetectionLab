# Source: https://github.com/StefanScherer/adfs2
param ([String] $ip, [String] $dns, [String] $gateway, [String] $dns2)

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Running fix-second-network.ps1..."

if ( (Get-NetAdapter | Select-Object -First 1 | Select-Object -ExpandProperty InterfaceDescription).Contains('Red Hat VirtIO')) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Setting Network Configuration for LibVirt interface"
  $subnet = $ip -replace "\.\d+$", ""
  $name = (Get-NetIPAddress -AddressFamily IPv4 `
     | Where-Object -FilterScript { ($_.IPAddress).StartsWith("$subnet") } `
     ).InterfaceAlias
  if ($name) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Set IP address to $ip of interface $name"
    & netsh.exe int ip set address "$name" static $ip 255.255.255.0 "$gateway"
    if ($dns) {
      Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Set DNS server address to $dns of interface $name"
      & netsh.exe interface ipv4 add dnsserver "$name" address=$dns index=1
    }
    if ($dns2) {
      & netsh.exe interface ipv4 add dnsserver "$name" address=$dns2 index=2
    }
  } else {
    Write-Error "Could not find a interface with subnet $subnet.xx"
  }
  exit 0
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) No VirtIO adapters, moving on..."
}

if (! (Test-Path 'C:\Program Files\VMware\VMware Tools') ) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) VMware Tools not found, no need to continue. Exiting."
  exit 0
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date))"
Write-Host "Setting IP address and DNS information for the Ethernet1 interface"
Write-Host "If this step times out, it's because vagrant is connecting to the VM on the wrong interface"
Write-Host "See https://github.com/clong/DetectionLab/issues/114 for more information"

$subnet = $ip -replace "\.\d+$", ""
$name = (Get-NetIPAddress -AddressFamily IPv4 `
   | Where-Object -FilterScript { ($_.IPAddress).StartsWith($subnet) } `
   ).InterfaceAlias
if (!$name) {
  $name = (Get-NetIPAddress -AddressFamily IPv4 `
     | Where-Object -FilterScript { ($_.IPAddress).StartsWith("169.254.") } `
     ).InterfaceAlias
}
if ($name) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Set IP address to $ip of interface $name"
  & netsh.exe int ip set address "$name" static $ip 255.255.255.0 "$subnet.1"
  if ($dns) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Set DNS server address to $dns of interface $name"
    & netsh.exe interface ipv4 add dnsserver "$name" address=$dns index=1
  }
  if ($dns2) {
    & netsh.exe interface ipv4 add dnsserver "$name" address=$dns2 index=2
  }
} else {
  Write-Error "$('[{0:HH:mm}]' -f (Get-Date)) Could not find a interface with subnet $subnet.xx"
}
