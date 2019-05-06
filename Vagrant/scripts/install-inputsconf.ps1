# Purpose: Configures the inputs.conf for the Splunk forwarders on the Windows hosts

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Setting up Splunk Inputs for Sysmon & osquery"

$inputsPath = "C:\Program Files\SplunkUniversalForwarder\etc\apps\SplunkUniversalForwarder\local\inputs.conf"
$currentContent = get-content $inputsPath
$targetContent = get-content c:\vagrant\resources\splunk_forwarder\inputs.conf

if ($currentContent -ne $targetContent)
{
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Stopping the Splunk forwarder"
  try {
    Stop-Service splunkforwarder -ErrorAction Stop
  } catch {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Failed to stop SplunkForwarder. Trying again..."
    Set-Location "C:\Program Files\SplunkUniversalForwarder\bin"
    & ".\splunk.exe" "stop"
  }

  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Deleting the default configuration"
  Remove-Item $inputsPath

  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Copying over the custom configuration"
  Copy-Item c:\vagrant\resources\splunk_forwarder\inputs.conf $inputsPath

  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Starting the Splunk forwarder"
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
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Splunk forwarder installation complete!"
