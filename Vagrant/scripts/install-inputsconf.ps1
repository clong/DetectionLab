# Purpose: Configures the inputs.conf for the Splunk forwarders on the Windows hosts

Write-Host "Setting up Splunk Inputs for Sysmon & osquery"
$inputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\apps\SplunkUniversalForwarder\local\inputs.conf"

Write-Host "Stopping the Splunk forwarder"
Stop-Service splunkforwarder

Write-Host "Deleting the default configuration"
Remove-Item $inputsPath

Write-Host "Copying over the custom configuration"
Copy-Item c:\vagrant\resources\splunk_forwarder\inputs.conf $inputsPath

Write-Host "Starting the Splunk forwarder"
Start-Service splunkforwarder
