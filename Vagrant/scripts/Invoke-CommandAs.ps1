# Based on research by James Forshaw (@tiraniddo)
# https://www.tiraniddo.dev/2019/09/the-art-of-becoming-trustedinstaller.html

function Invoke-CommandAs {
    param (
        [Parameter(Position=0)][String]$User,
        [Parameter(Position=1)][ScriptBlock]$ScriptBlock
    )

    $LogFile = New-TemporaryFile
    $ScriptFile = New-TemporaryFile

    "Invoke-Command { $ScriptBlock } *> $LogFile" | Out-File $ScriptFile
    $ScriptFile = Rename-Item $ScriptFile "$($ScriptFile.BaseName).ps1" -PassThru

    $TaskName = 'Invoke-CommandAs Task'
    $TaskAction = New-ScheduledTaskAction `
        -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptFile"
    Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Force | Out-Null

    ($ScheduleService = New-Object -ComObject Schedule.Service).Connect()
    $ScheduleService.GetFolder('\').GetTask($TaskName).RunEx($null, 0, 0, $User) | Out-Null

    while ((Get-ScheduledTask $TaskName).State -eq 'Running') { Start-Sleep 0.5 }

    if (($Result = (Get-ScheduledTaskInfo $TaskName).LastTaskResult) -ne 0) {
        throw "The scheduled task '$TaskName' failed with result code $Result."
    }

    Unregister-ScheduledTask $TaskName -Confirm:$false
    Get-Content $LogFile
    Remove-Item $LogFile, $ScriptFile
}
