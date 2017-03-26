Write-Host "WARNING: DO NOT USE DOCKER IN PRODUCTION WITHOUT TLS"
Write-Host "Opening Docker insecure port 2375"

if (!(Get-NetFirewallRule | where {$_.Name -eq "Dockerinsecure2375"})) {
    New-NetFirewallRule -Name "Dockerinsecure2375" -DisplayName "Docker insecure on TCP/2375" -Protocol tcp -LocalPort 2375 -Action Allow -Enabled True
}
