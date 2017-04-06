Write-Host "Installing Sysmon TA for Splunk"

# Install Sysmon TA
$timeoutSeconds = 10
$sysmontaPath = "C:\vagrant\resources\add-on-for-microsoft-sysmon_600.tgz"

$j = Start-Job -ScriptBlock {
  Start-Process -FilePath "C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe" -ArgumentList "install app $sysmontaPath -auth 'admin:changeme'"
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
$inputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\apps\TA-microsoft-sysmon\local\inputs.conf"
New-Item -ItemType Directory -Force -Path "C:\Program Files\SplunkUniversalForwarder\etc\apps\TA-microsoft-sysmon\local"
Copy-Item c:\vagrant\resources\sysmon_inputs.conf $inputsPath

# Add a check here to make sure everything was installed correctly
If(!(test-path $inputsPath)) {
  Write-Host "Something went wrong during installation."
  exit 1
} Else {
  Write-Host "Sysmon TA installed successfully."
}
