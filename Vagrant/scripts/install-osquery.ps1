# Purpose: Installs osquery on the host
# Note: by default, osquery will be configured to connect to the Fleet server on the "logger" host via TLS.
# If you would like to have osquery run without TLS & Fleet, uncomment line 15 and comment lines 21-30.

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing osquery..."
$packsDir = "c:\Program Files\osquery\packs"
choco install -y --limit-output --no-progress osquery | Out-String  # Apparently Out-String makes the process wait
$service = Get-WmiObject -Class Win32_Service -Filter "Name='osqueryd'"
If (-not ($service)) {
  Write-Host "Setting osquery to run as a service"
  Start-Process -FilePath "c:\Program Files\osquery\osqueryd\osqueryd.exe" -ArgumentList "--install" -Wait
  # Copy over the config and packs from the Palantir repo
  Copy-Item "c:\Users\vagrant\AppData\Local\Temp\osquery-configuration-master\Classic\Endpoints\Windows\*" "c:\Program Files\osquery" -Force
  Copy-Item "c:\Users\vagrant\AppData\Local\Temp\osquery-configuration-master\Classic\Endpoints\packs" -Path "c:\Program Files\osquery" -Force

  ## Use the TLS config by default. Un-comment the line below to use the local configuration and avoid connecting to Fleet.
  # Copy-Item "c:\ProgramData\osquery\osquery_no_tls.flags" -Path "c:\ProgramData\osquery\osquery.flags" -Force

  ###  --- TLS CONFIG BEGINS ---
  ### COMMENT ALL LINES BELOW UNTIL "TLS CONFIG ENDS" if using local configuration
  ## Add entry to hosts file for Kolide for SSL validation
  Add-Content "c:\windows\system32\drivers\etc\hosts" "        192.168.38.105    kolide"
  ## Add kolide secret and avoid BOM
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
  [System.IO.File]::WriteAllLines("c:\Program Files\osquery\kolide_secret.txt", "enrollmentsecret", $Utf8NoBomEncoding)
  ## Change TLS server hostname
  (Get-Content "c:\Program Files\osquery\osquery.flags") -replace 'tls.endpoint.server.com', 'kolide:8412' | Set-Content "c:\Program Files\osquery\osquery.flags"
  ## Change path to secrets
  (Get-Content "c:\Program Files\osquery\osquery.flags") -replace 'path\\to\\file\\containing\\secret.txt', 'Program Files\osquery\kolide_secret.txt' | Set-Content "c:\Program Files\osquery\osquery.flags"
  ## Add certfile.crt
  Copy-Item "c:\vagrant\resources\fleet\server.crt" "c:\Program Files\osquery\certfile.crt"
  ### --- TLS CONFIG ENDS ---

  Stop-service osqueryd
  Start-Sleep -s 5
  Start-Service osqueryd
}
else {
  Write-Host "osquery is already installed. Moving On."
}
If ((Get-Service -name osqueryd).Status -ne "Running")
{
  throw "osqueryd service was not running"
}
