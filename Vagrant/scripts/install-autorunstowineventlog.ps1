Write-Host "Installing AutorunsToWinEventLog..."
cd "c:\vagrant\resources\windows-event-forwarding-master\AutorunsToWinEventLog"
.\Install.ps1
Write-Host "AutorunsToWinEventLog installed. Starting the scheduled task. Future runs will begin at 11am"
Start-ScheduledTask -TaskName "AutorunsToWinEventLog"
