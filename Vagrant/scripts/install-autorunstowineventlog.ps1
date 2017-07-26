Write-Host "Installing AutorunsToWinEventLog..."
New-Item -ItemType Directory -Force -Path "c:\Tools\AutorunsToWinEventLog"
Expand-Archive c:\vagrant\resources\AutorunsToWinEventLog.zip -DestinationPath c:\Tools\AutorunsToWinEventLog
c:\Tools\AutorunsToWinEventLog\Install.ps1
Write-Host "AutorunsToWinEventLog installed. Starting the scheduled task. Future runs will begin at 11am"
Start-ScheduledTask -TaskName "AutorunsToWinEventLog"
