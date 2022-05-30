# Purpose: Installs osquery on the host. Osquery conntects to Fleet via TLS.

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing osquery..."
$flagfile = "c:\Program Files\osquery\osquery.flags"
choco install -y --limit-output --no-progress osquery | Out-String  # Apparently Out-String makes the process wait
$service = Get-WmiObject -Class Win32_Service -Filter "Name='osqueryd'"
If (-not ($service)) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Setting osquery to run as a service"
  New-Service -Name "osqueryd" -BinaryPathName "C:\Program Files\osquery\osqueryd\osqueryd.exe --flagfile=`"C:\Program Files\osquery\osquery.flags`""

  # Download the flags file from the Palantir osquery-configuration Github
  # GitHub requires TLS 1.2 as of 2/1/2018
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  # Disabling the progress bar speeds up IWR https://github.com/PowerShell/PowerShell/issues/2138
  $ProgressPreference = 'SilentlyContinue'
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/palantir/osquery-configuration/master/Classic/Endpoints/Windows/osquery.flags" -OutFile $flagfile

  ## Use the TLS config
  ## Add entry to hosts file for Fleet for SSL validation
  If (Select-String -Path "c:\windows\system32\drivers\etc\hosts" -Pattern "fleet") {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Hosts file already updated. Moving on."
  }
  Else {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Adding Fleet to the hosts file"
    Add-Content "c:\windows\system32\drivers\etc\hosts" "        192.168.56.105    fleet"
  }
  ## Add Fleet secret and avoid BOM
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
  [System.IO.File]::WriteAllLines("c:\Program Files\osquery\fleet_secret.txt", "enrollmentsecretenrollmentsecret", $Utf8NoBomEncoding)
  ## Change TLS server hostname in the flags file
  (Get-Content $flagfile) -replace 'tls.endpoint.server.com', 'fleet:8412' | Set-Content $flagfile
  ## Change path to secrets in the flags file
  (Get-Content $flagfile) -replace 'path\\to\\file\\containing\\secret.txt', 'Program Files\osquery\fleet_secret.txt' | Set-Content $flagfile
  ## Change path to certfile in the flags file
  (Get-Content $flagfile) -replace 'c:\\ProgramData\\osquery\\certfile.crt', 'c:\Program Files\osquery\certfile.crt' | Set-Content $flagfile
  ## Remove the verbose flag and replace it with the logger_min_status=1 option (See https://github.com/osquery/osquery/issues/5212)
  (Get-Content $flagfile) -replace '--verbose=true', '--logger_min_status=1' | Set-Content $flagfile
  ## Add certfile.crt
  Copy-Item "c:\vagrant\resources\fleet\server.crt" "c:\Program Files\osquery\certfile.crt"
  ## Start the service
  Start-Service osqueryd
}
else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) osquery is already installed. Moving On."
}
If ((Get-Service -name osqueryd).Status -ne "Running")
{
  throw "osqueryd service was not running"
}
