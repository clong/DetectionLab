# Source: https://github.com/StefanScherer/adfs

param ([String] $ip, [String] $dns)

Write-Host "$('[{0:HH:mm}]' -f (Get-Date))"
Write-Host "Setting IP address and DNS information."
Write-Host "If this step times out, it's because vagrant is connecting to the VM on the wrong interface"
Write-Host "See https://github.com/clong/DetectionLab/issues/114 for more information"

$subnet = $ip -replace "\.\d+$", ""
$name = (Get-NetIPAddress -AddressFamily IPv4 `
   | Where-Object -FilterScript { ($_.IPAddress).StartsWith("169") } `
   ).InterfaceAlias
if (!$name) {
  $name = (Get-NetIPAddress -AddressFamily IPv4 `
     | Where-Object -FilterScript { ($_.IPAddress).StartsWith("192.168.56") } `
     ).InterfaceAlias
}
if ($name) {
  Write-Host "Set IP address to $ip of interface $name"
  & netsh.exe int ip set address $name static $ip 255.255.255.0 "$subnet.1"
  Write-Host "Set DNS server address to $dns of interface $name"
  & netsh.exe interface ipv4 add dnsserver $name address=192.168.56.102 index=1
  if ($dns) {
    & netsh.exe interface ipv4 add dnsserver $name address=$dns index=2
  }
} else {
  Write-Error "Could not find a interface with subnet $subnet.xx"
}
