# Purpose: Installs the Caldera agent on the host

# Add /etc/hosts entry
Add-Content "c:\windows\system32\drivers\etc\hosts" "        192.168.38.5    logger"

# Make the directory
New-Item "c:\Program Files\cagent" -type directory

# Install Visual Studio 2015 C++ Redistributable
choco install -y vcredist2015

# Download cagent and start the service
If (-not (Test-Path "C:\Program Files\cagent\cagent.exe")) {
  Write-Host "Downloading Caldera Agent (cagent.exe)"
  $cagentPath = "C:\Program Files\cagent\cagent.exe"
  $cagentConfPath = "C:\Program Files\cagent\conf.yml"
  (New-Object System.Net.WebClient).DownloadFile('https://github.com/mitre/caldera-agent/releases/download/v0.1.0/cagent.exe', $cagentPath)
  # Ignore SSL warning for conf file download
  # https://stackoverflow.com/questions/34331206/ignore-ssl-warning-with-powershell-downloadstring
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} ;(New-Object System.Net.WebClient).DownloadFile('https://logger:8888/conf.yml', $cagentConfPath)
  Start-Process -FilePath $cagentPath -ArgumentList '--startup', 'auto', 'install' -Wait
  Start-Process -FilePath $cagentPath -ArgumentList 'start' -Wait
} Else {
  Write-Host "Caldera Agent is already installed. Moving on."
}
Write-Host "Cagent installation complete!"
