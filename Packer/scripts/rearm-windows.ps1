# Replaces "slmgr.vbs /rearm"
# https://powershell.org/forums/topic/run-command-quietly-start-process/
# https://msdn.microsoft.com/en-us/library/ee957713(v=vs.85).aspx

Write-Host "Resetting the Windows evaluation timer"

$x = Get-WmiObject SoftwarelicensingService
$x.ReArmWindows()
