# Purpose: Installs a handful of SysInternals tools on the host into c:\Tools\Sysinternals

$sysinternalsDir = "C:\Tools\Sysinternals"
$sysmonDir = "C:\ProgramData\Sysmon"
If(!(test-path $sysinternalsDir)) {
  New-Item -ItemType Directory -Force -Path $sysinternalsDir
} Else {
  Write-Host "Tools directory exists. Exiting."
  exit
}

If(!(test-path $sysmonDir)) {
  New-Item -ItemType Directory -Force -Path $sysmonDir
} Else {
  Write-Host "Sysmon directory exists. Exiting."
  exit
}

$autorunsPath = "C:\Tools\Sysinternals\Autoruns64.exe"
$procmonPath = "C:\Tools\Sysinternals\Procmon.exe"
$psexecPath = "C:\Tools\Sysinternals\PsExec64.exe"
$procexpPath = "C:\Tools\Sysinternals\procexp64.exe"
$sysmonPath = "C:\Tools\Sysinternals\Sysmon64.exe"
$tcpviewPath = "C:\Tools\Sysinternals\Tcpview.exe"
$sysmonConfigPath = "$sysmonDir\sysmonConfig.xml"

Write-Host "Downloading Autoruns64.exe..."
Invoke-WebRequest -Uri "https://live.sysinternals.com/Autoruns64.exe" -OutFile $autorunsPath
Write-Host "Downloading Procmon.exe..."
Invoke-WebRequest -Uri "https://live.sysinternals.com/Procmon.exe" -OutFile $procmonPath
Write-Host "Downloading PsExec64.exe..."
Invoke-WebRequest -Uri "https://live.sysinternals.com/PsExec64.exe" -OutFile $psexecPath
Write-Host "Downloading procexp64.exe..."
Invoke-WebRequest -Uri "https://live.sysinternals.com/procexp64.exe" -OutFile $procexpPath
Write-Host "Downloading Sysmon64.exe..."
Invoke-WebRequest -Uri "https://live.sysinternals.com/Sysmon64.exe" -Outfile $sysmonPath
Write-Host "Downloading Tcpview.exe..."
Invoke-WebRequest -Uri "https://live.sysinternals.com/Tcpview.exe" -Outfile $tcpviewPath
Copy-Item $sysmonPath $sysmonDir

# Download SwiftOnSecurity's Sysmon config
Write-Host "Downloading SwiftOnSecurity's Sysmon config..."
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -Outfile "$sysmonConfigPath"
# Alternative: Download Olaf Hartong's Sysmon config (more CPU intensive)
#Invoke-WebRequest -Uri "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" -Outfile "$sysmonConfigPath"

# Start Sysmon
Write-Host "Starting Sysmon..."
Start-Process -FilePath "$sysmonDir\Sysmon64.exe" -ArgumentList "-accepteula -i $sysmonConfigPath"
Write-Host "Verifying that the Sysmon service is running..."
Start-Sleep 5 # Give the service time to start
If ((Get-Service -name Sysmon64).Status -ne "Running")
{
  throw "The Sysmon service did not start successfully"
}
