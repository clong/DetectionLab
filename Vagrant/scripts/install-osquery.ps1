Write-Host "Installing osquery"
$packsDir = "c:\programdata\osquery\packs"
choco install -y osquery | Out-String  # Apparently Out-String makes the process wait
$service = Get-WmiObject -Class Win32_Service -Filter "Name='osqueryd'"
If (-not ($service)) {
  Write-Host "Setting osquery to run as a service"
  Start-Process -FilePath "c:\programdata\osquery\osqueryd\osqueryd.exe" -ArgumentList "--install" -Wait
  # Copy over the config
  Copy-Item c:\vagrant\resources\osquery\osquery.conf c:\programdata\osquery\osquery.conf
  #TODO: Fix up autoruns.conf
  # Create the query packs directory
  #New-Item -ItemType Directory -Force -Path $packsDir
  # Copy over custom pack
  #Copy-Item c:\vagrant\resources\autoruns.conf $packsDir
  Stop-service osqueryd
  Start-Sleep -s 5
  Start-Service osqueryd
}
else {
  Write-Host "osquery is already installed"
}
