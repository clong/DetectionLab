# Purpose: Installs AutorunsToWinEventLog from the Palantir WEF repo: (https://github.com/palantir/windows-event-forwarding/tree/master/AutorunsToWinEventLog)
# TL;DR - Logs all entries from Autoruns to the Windows event log to be indexed by Splunk
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing AutorunsToWinEventLog..."
If ((Get-ScheduledTask -TaskName "AutorunsToWinEventLog" -ea silent) -eq $null)
{
    # Modify the installer to add an HTTP fallback until this gets fixed upstream in the windows-event-fowarding repo
    # See https://github.com/clong/DetectionLab/issues/597
    (Get-Content c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\AutorunsToWinEventLog\Install.ps1 -Raw) -replace 'Invoke-WebRequest -Uri "https://live.sysinternals.com/autorunsc64.exe" -OutFile "\$autorunsPath"', 'Try {
    (New-Object System.Net.WebClient).DownloadFile(''https://live.sysinternals.com/Autoruns64.exe'', $autorunsPath)
  } Catch {
    Write-Host "HTTPS connection failed. Switching to HTTP :("
    (New-Object System.Net.WebClient).DownloadFile(''http://live.sysinternals.com/Autoruns64.exe'', $autorunsPath)
  }' | Set-Content -Path "c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\AutorunsToWinEventLog\Install.ps1"
    . c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\AutorunsToWinEventLog\Install.ps1
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) AutorunsToWinEventLog installed. Starting the scheduled task. Future runs will begin at 11am"
    Start-ScheduledTask -TaskName "AutorunsToWinEventLog"
    # https://mcpmag.com/articles/2018/03/16/wait-action-function-powershell.aspx
    # Wait 30 seconds for the scheduled task to enter the "Running" state
    $Timeout = 30
    $timer = [Diagnostics.Stopwatch]::StartNew()
    while (($timer.Elapsed.TotalSeconds -lt $Timeout) -and ((Get-ScheduledTask -TaskName "AutorunsToWinEventLog").State -ne "Running")) {
        Start-Sleep -Seconds 3
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Still waiting for scheduled task to start after "$timer.Elapsed.Seconds" seconds..."
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
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) AutorunsToWinEventLog already installed. Moving On."
}
