Write-Host "Invoke-AtomicTest has been loaded."
Write-Host "Learn more about atomic tests here: https://git.io/Jed0L"
Write-Host ""
Import-Module "C:\Tools\Atomic Red Team\atomic-red-team-master\execution-frameworks\Invoke-AtomicRedTeam\Invoke-AtomicRedTeam\Invoke-AtomicRedTeam.psm1"
$PSDefaultParameterValues = @{"Invoke-AtomicTest:PathToAtomicsFolder"="C:\Tools\Atomic Red Team\atomic-red-team-master\atomics"}