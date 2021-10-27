# Purpose: Installs a Splunk Universal Forwader on the host

If (-not (Test-Path "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe")) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Splunk Universal Forwarder..."
  $msiFile = $env:Temp + "\splunkforwarder-8.1.0.1-24fd52428b5a-x64-release.msi"

  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing & Starting Splunk"
  [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
  (New-Object System.Net.WebClient).DownloadFile('https://download.splunk.com/products/universalforwarder/releases/8.2.2.1/windows/splunkforwarder-8.2.2.1-ae6821b7c64b-x64-release.msi', $msiFile)
  Start-Process -FilePath "c:\windows\system32\msiexec.exe" -ArgumentList '/i', "$msiFile", 'RECEIVING_INDEXER="192.168.56.105:9997" WINEVENTLOG_SEC_ENABLE=0 WINEVENTLOG_SYS_ENABLE=0 WINEVENTLOG_APP_ENABLE=0 AGREETOLICENSE=Yes SERVICESTARTTYPE=AUTO LAUNCHSPLUNK=1 SPLUNKPASSWORD=changeme /quiet' -Wait
}
Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Splunk is already installed. Moving on."
}
If ((Get-Service -name splunkforwarder).Status -ne "Running") {
  throw "Splunk forwarder service not running"
}
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Splunk installation complete!"
