Write-Host "Installing AutorunsToWEF..."
Expand-Archive c:\vagrant\resources\AutorunsToWEF-master.zip -DestinationPath c:\Tools
c:\Tools\AutorunsToWEF-master\Install.ps1
Write-Host "AutorunsToWEF installed. Starting the scheduled task."
Start-ScheduledTask -TaskName "AutorunsToWEF"
