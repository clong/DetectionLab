# Purpose: Installs a Splunk Universal Forwader on the host

If (-not (Test-Path "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe")) {
  Write-Host "Downloading Splunk"
  $msiFile = $env:Temp + "\splunkforwarder-6.5.2-67571ef4b87d-x64-release.msi"

  Write-Host "Installing & Starting Splunk"
  (New-Object System.Net.WebClient).DownloadFile('https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=windows&version=6.5.2&product=universalforwarder&filename=splunkforwarder-6.5.2-67571ef4b87d-x64-release.msi&wget=true', $msiFile)
  Start-Process -FilePath "c:\windows\system32\msiexec.exe" -ArgumentList '/i', "$msiFile", 'RECEIVING_INDEXER="192.168.38.5:9997" WINEVENTLOG_SEC_ENABLE=1 WINEVENTLOG_SYS_ENABLE=1 WINEVENTLOG_APP_ENABLE=1 AGREETOLICENSE=Yes SERVICESTARTTYPE=1 LAUNCHSPLUNK=1 /quiet' -Wait
} Else {
  Write-Host "Splunk is already installed. Moving on."
}
Write-Host "Splunk installation complete!"
