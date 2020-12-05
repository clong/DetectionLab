Import-Module "C:\Tools\Atomic Red Team\atomic-red-team-master\execution-frameworks\Invoke-AtomicRedTeam\Invoke-AtomicRedTeam\Invoke-AtomicRedTeam.psm1"
$PSDefaultParameterValues = @{"Invoke-AtomicTest:PathToAtomicsFolder"="C:\Tools\Atomic Red Team\atomic-red-team-master\atomics"}
$env:Path += ";c:\Program Files\osquery"