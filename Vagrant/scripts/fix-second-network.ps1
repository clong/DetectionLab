# Source: https://github.com/StefanScherer/adfs2
param ([String] $ip, [String] $dns)

if (Test-Path C:\Users\vagrant\enable-winrm-after-customization.bat) {
  Write-Host "Nothing to do in vCloud."
  exit 0
}
if (! (Test-Path 'C:\Program Files\VMware\VMware Tools')) {
  Write-Host "Nothing to do for other providers than VMware."
  exit 0
}

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
  Write-Host "Set IP address to $ip of interface $name"
  & netsh.exe int ip set address "$name" static $ip 255.255.255.0 "$subnet.1"

  if ($dns) {
    Write-Host "Set DNS server address to $dns of interface $name"
    & netsh.exe interface ipv4 add dnsserver "$name" address=$dns index=1
  }
} else {
  Write-Error "Could not find a interface with subnet $subnet.xx"
}
