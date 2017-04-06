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

# Add check here to make sure it installed correctly
Write-Host "Windows TA installed successfully"
