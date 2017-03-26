$sysinternalsDir = "C:\Tools\Sysinternals"
$sysmonDir = "C:\ProgramData\Sysmon"
If(!(test-path $sysinternalsDir)) {
  New-Item -ItemType Directory -Force -Path $sysinternalsDir
} Else {
  Write-Host "Tools directory exists. Moving on."
  exit
}

If(!(test-path $sysmonDir)) {
  New-Item -ItemType Directory -Force -Path $sysmonDir
} Else {
  Write-Host "Sysmon directory exists. Moving on."
  exit
}

$autorunsPath = "C:\Tools\Sysinternals\Autoruns64.exe"
$procmonPath = "C:\Tools\Sysinternals\Procmon.exe"
$psexecPath = "C:\Tools\Sysinternals\PsExec64.exe"
$procexpPath = "C:\Tools\Sysinternals\procexp64.exe"
$sysmonPath = "C:\Tools\Sysinternals\Sysmon64.exe"
$sysmonConfigPath = "$sysmonDir\sysmonConfig.xml"

Invoke-WebRequest -Uri "https://live.sysinternals.com/Autoruns64.exe" -OutFile $autorunsPath
Invoke-WebRequest -Uri "https://live.sysinternals.com/Procmon.exe" -OutFile $procmonPath
Invoke-WebRequest -Uri "https://live.sysinternals.com/PsExec64.exe" -OutFile $psexecPath
Invoke-WebRequest -Uri "https://live.sysinternals.com/procexp64.exe" -OutFile $procexpPath
Invoke-WebRequest -Uri "https://live.sysinternals.com/Sysmon64.exe" -Outfile $sysmonPath
Copy-Item $sysmonPath $sysmonDir
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -Outfile "$sysmonDir\sysmonConfig.xml"

# Startup Sysmon
Write-Host "Starting Sysmon..."
Start-Process -FilePath "$sysmonDir\Sysmon64.exe" -ArgumentList "-accepteula -i $sysmonConfigPath"
