# Purpose: Installs AutorunsToWinEventLog from the Palantir WEF repo: (https://github.com/palantir/windows-event-forwarding/tree/master/AutorunsToWinEventLog)
# TL;DR - Logs all entries from Autoruns to the Windows event log to be indexed by Splunk
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing AutorunsToWinEventLog..."
If ((Get-ScheduledTask -TaskName "AutorunsToWinEventLog" -ea silent) -eq $null)
{
    . c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\AutorunsToWinEventLog\Install.ps1
    Write-Host "AutorunsToWinEventLog installed. Starting the scheduled task. Future runs will begin at 11am"
    Start-ScheduledTask -TaskName "AutorunsToWinEventLog"
    # https://mcpmag.com/articles/2018/03/16/wait-action-function-powershell.aspx
    # Wait 30 seconds for the scheduled task to enter the "Running" state
    $Timeout = 30
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (($timer.Elapsed.TotalSeconds -lt $Timeout) -and ((Get-ScheduledTask -TaskName "AutorunsToWinEventLog").State -ne "Running")) {
        Start-Sleep -Seconds 3
        Write-Host "Still waiting for scheduled task to start after "$timer.Elapsed.Seconds" seconds..."
    }
    $timer.Stop()
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
