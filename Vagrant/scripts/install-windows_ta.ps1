Write-Host "Installing the Windows TA for Splunk"

# Install Windows TA (this only needs to be done on the WEF server)
$timeoutSeconds = 10
$windowstaPath = "C:\vagrant\resources\splunk-add-on-for-microsoft-windows_483.tgz"

$j = Start-Job -ScriptBlock {
  Start-Process -FilePath "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" -ArgumentList "install app $windowstaPath -auth 'admin:changeme'"
}
Wait-Job $j -Timeout $timeoutSeconds | out-null
if ($j.State -eq "Completed") {
  Write-Host "Done."
} Elseif ($j.State -eq "Running") {
  Write-Host "Killing this job after $timeoutSeconds seconds"
} Else {
Write-Host "Error"
}
Remove-Job -force $j
# Create local directory
$inputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\apps\Splunk_TA_windows\local\inputs.conf"
New-Item -ItemType Directory -Force -Path "C:\Program Files\SplunkUniversalForwarder\etc\apps\Splunk_TA_windows\local"
Copy-Item c:\vagrant\resources\windows_inputs.conf $inputsPath

# Add a check here to make sure everything was installed correctly
If(!(test-path $inputsPath)) {
  Write-Host "Windows TA installed successfully."
} Else {
  Write-Host "Something went wrong during installation."
  exit 1
}
