Write-Host "Installing osquery"
choco install -y osquery | Out-String  # Apparently Out-String makes the process wait
$service = Get-WmiObject -Class Win32_Service -Filter "Name='osqueryd'"
If (-not ($service)) {
  Write-Host "Setting osquery to run as a service"
  Start-Process -FilePath "c:\programdata\osquery\osqueryd\osqueryd.exe" -ArgumentList "--install" -Wait
  # Do more things like copy over the config, flags, etc
}
else {
  Write-Host "osquery is already installed"
}
