# This only needs to be installed on the WEF server
Write-Host "Installing the Windows TA for Splunk"

If (test-path "C:\Program Files\SplunkUniversalForwarder\etc\apps\Splunk_TA_windows\default") {
  Write-Host "Windows TA is already installed. Moving on."
  Exit
}

# Install Windows TA (this only needs to be done on the WEF server)
$windowstaPath = "C:\vagrant\resources\splunk_forwarder\splunk-add-on-for-microsoft-windows_483.tgz"
$inputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\apps\Splunk_TA_windows\local\inputs.conf"
Write-Host "Installing the Windows TA"
Start-Process -FilePath "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" -ArgumentList "install app $windowstaPath -auth admin:changeme" -NoNewWindow

# Create local directory
New-Item -ItemType Directory -Force -Path "C:\Program Files\SplunkUniversalForwarder\etc\apps\Splunk_TA_windows\local"
Copy-Item c:\vagrant\resources\splunk_forwarder\wef_inputs.conf $inputsPath

# Add a check here to make sure the TA was installed correctly
Write-Host "Sleeping for 15 seconds"
start-sleep -s 15
If (test-path "C:\Program Files\SplunkUniversalForwarder\etc\apps\Splunk_TA_windows\default") {
  Write-Host "Windows TA installed successfully."
} Else {
  Write-Host "Something went wrong during installation."
  exit 1
}
