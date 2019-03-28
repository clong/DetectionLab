# Purpose: Installs the Caldera agent on the host

If (-not (Test-Path 'C:\Program Files\cagent\cagent.exe')) {
  # Add /etc/hosts entry
  Add-Content "c:\windows\system32\drivers\etc\hosts" "        192.168.38.105    logger"

  # Make the directory
  New-Item "c:\Program Files\cagent" -type directory

  # Install Visual Studio 2015 C++ Redistributable
  choco install -y vcredist2015

  # Download cagent and start the service
  Write-Host "Downloading Caldera Agent (cagent.exe)"
  $cagentPath = "C:\Program Files\cagent\cagent.exe"
  $cagentConfPath = "C:\Program Files\cagent\conf.yml"
  # GitHub requires TLS 1.2 as of 2/1/2018
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  (New-Object System.Net.WebClient).DownloadFile('https://github.com/mitre/caldera-agent/releases/download/v0.1.0/cagent.exe', $cagentPath)
  # Copy hardocded Caldera config from the Vagrant resources folder
  Copy-Item "C:\vagrant\resources\caldera\conf.yml" $cagentConfPath -Force
  If (-not (Test-Path "$cagentConfPath" )) {
    Write-Host "Caldera Agent configuration failed. Unable to retrieve config from resources folder."
  }
  Start-Process -FilePath $cagentPath -ArgumentList '--startup', 'auto', 'install' -Wait
  Start-Process -FilePath $cagentPath -ArgumentList 'start' -Wait
} Else {
  Write-Host "Caldera Agent is already installed. Moving on."
}
Start-Sleep 5
If ((Get-Service -name cagent).Status -ne "Running") {
  throw "Caldera Agent service not running"
}
Write-Host "Cagent installation complete!"
