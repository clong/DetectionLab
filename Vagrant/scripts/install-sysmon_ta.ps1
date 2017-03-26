Write-Host "Installing Sysmon TA for Splunk"

# Install Sysmon TA
$timeoutSeconds = 10
$sysmontaPath = "C:\Users\vagrant\Desktop\resources\add-on-for-microsoft-sysmon_600.tgz"
Invoke-WebRequest -Uri "https://github.com/Centurion89/resources/raw/master/add-on-for-microsoft-sysmon_600.tgz" -OutFile $sysmontaPath

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
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Centurion89/resources/master/sysmon_inputs.conf" -OutFile $inputsPath

# Add a check here to make sure everything was installed correctly
If(!(test-path $inputsPath)) {
  Write-Host "Sysmon TA installed successfully."
} Else {
  Write-Host "Something went wrong during installation."
  exit 1
}
