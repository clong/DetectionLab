# Purpose: Configures the inputs.conf for the Splunk forwarders on the Windows hosts

Write-Host "Setting up Splunk Inputs for Sysmon & osquery"

$inputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\apps\SplunkUniversalForwarder\local\inputs.conf"
$currentContent = get-content $inputsPath
$targetContent = get-content c:\vagrant\resources\splunk_forwarder\inputs.conf

if ($currentContent -ne $targetContent)
{
    Write-Host "Stopping the Splunk forwarder"
    Stop-Service splunkforwarder

    Write-Host "Deleting the default configuration"
    Remove-Item $inputsPath

    Write-Host "Copying over the custom configuration"
    Copy-Item c:\vagrant\resources\splunk_forwarder\inputs.conf $inputsPath

    Write-Host "Starting the Splunk forwarder"
    Start-Service splunkforwarder
}
else
{
    Write-Host "Splunk forwarder already configured. Moving on."
}
If ((Get-Service -name splunkforwarder).Status -ne "Running")
{
    throw "splunkforwarder service was not running."
}
Write-Host "Splunk forwarder installation complete!"
