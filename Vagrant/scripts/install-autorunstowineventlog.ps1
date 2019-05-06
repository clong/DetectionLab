# Purpose: Installs AutorunsToWinEventLog from the Palantir WEF repo: (https://github.com/palantir/windows-event-forwarding/tree/master/AutorunsToWinEventLog)
# TL;DR - Logs all entries from Autoruns to the Windows event log to be indexed by Splunk
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing AutorunsToWinEventLog..."
If ((Get-ScheduledTask -TaskName "AutorunsToWinEventLog" -ea silent) -eq $null)
{
    . c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\AutorunsToWinEventLog\Install.ps1
    Write-Host "AutorunsToWinEventLog installed. Starting the scheduled task. Future runs will begin at 11am"
    Start-ScheduledTask -TaskName "AutorunsToWinEventLog"
    $Tsk = Get-ScheduledTask -TaskName "AutorunsToWinEventLog"
    if ($Tsk.State -ne "Running")
    {
        throw "AutorunsToWinEventLog scheduled tasks wasn't running after starting it"
    }
}
else
{
    Write-Host "AutorunsToWinEventLog already installed. Moving On."
}
