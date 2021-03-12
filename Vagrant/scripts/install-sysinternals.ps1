# Purpose: Installs a handful of SysInternals tools on the host into c:\Tools\Sysinternals
# Also installs Sysmon and Olaf Harton's Sysmon config

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing SysInternals Tooling..."
$sysinternalsDir = "C:\Tools\Sysinternals"
$sysmonDir = "C:\ProgramData\Sysmon"
If(!(test-path $sysinternalsDir)) {
  New-Item -ItemType Directory -Force -Path $sysinternalsDir
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Tools directory exists, no need to re-install. Exiting."
  exit
}

If(!(test-path $sysmonDir)) {
  New-Item -ItemType Directory -Force -Path $sysmonDir
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Sysmon directory exists, no need to re-install. Exiting."
  exit
}

$autorunsPath = "C:\Tools\Sysinternals\Autoruns64.exe"
$procmonPath = "C:\Tools\Sysinternals\Procmon.exe"
$psexecPath = "C:\Tools\Sysinternals\PsExec64.exe"
$procexpPath = "C:\Tools\Sysinternals\procexp64.exe"
$sysmonPath = "C:\Tools\Sysinternals\Sysmon64.exe"
$tcpviewPath = "C:\Tools\Sysinternals\Tcpview.exe"
$sysmonConfigPath = "$sysmonDir\sysmonConfig.xml"
$shortcutLocation = "$ENV:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\"

$WScriptShell = New-Object -ComObject WScript.Shell

# Microsoft likes TLSv1.2 as well
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Autoruns64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/Autoruns64.exe', $autorunsPath) 
} Catch { 
  Write-Host "HTTPS connection failed. Switching to HTTP :("
  (New-Object System.Net.WebClient).DownloadFile('http://live.sysinternals.com/Autoruns64.exe', $autorunsPath) 
}
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation + "Autoruns.lnk")
$Shortcut.TargetPath = $autorunsPath
$Shortcut.Save()

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Procmon.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/Procmon.exe', $procmonPath)
} Catch { 
  Write-Host "HTTPS connection failed. Switching to HTTP :("
  (New-Object System.Net.WebClient).DownloadFile('http://live.sysinternals.com/Procmon.exe', $procmonPath)
}
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation + "Process Monitor.lnk")
$Shortcut.TargetPath = $procmonPath
$Shortcut.Save()

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading PsExec64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/PsExec64.exe', $psexecPath)
} Catch { 
  Write-Host "HTTPS connection failed. Switching to HTTP :("
  (New-Object System.Net.WebClient).DownloadFile('http://live.sysinternals.com/PsExec64.exe', $psexecPath)
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading procexp64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/procexp64.exe', $procexpPath)
} Catch { 
  Write-Host "HTTPS connection failed. Switching to HTTP :("
  (New-Object System.Net.WebClient).DownloadFile('http://live.sysinternals.com/procexp64.exe', $procexpPath)
}
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation + "Process Explorer.lnk")
$Shortcut.TargetPath = $procexpPath
$Shortcut.Save()

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Sysmon64.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/Sysmon64.exe', $sysmonPath)
} Catch { 
  Write-Host "HTTPS connection failed. Switching to HTTP :("
  (New-Object System.Net.WebClient).DownloadFile('http://live.sysinternals.com/Sysmon64.exe', $sysmonPath)
}
Copy-Item $sysmonPath $sysmonDir

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Tcpview.exe..."
Try { 
  (New-Object System.Net.WebClient).DownloadFile('https://live.sysinternals.com/Tcpview.exe', $tcpviewPath)
} Catch { 
  Write-Host "HTTPS connection failed. Switching to HTTP :("
  (New-Object System.Net.WebClient).DownloadFile('http://live.sysinternals.com/Tcpview.exe', $tcpviewPath)
}
$Shortcut = $WScriptShell.CreateShortcut($ShortcutLocation + "Tcpview.lnk")
$Shortcut.TargetPath = $tcpviewPath
$Shortcut.Save()

# Restart Explorer so the taskbar shortcuts show up
if (Get-Process -ProcessName explorer -ErrorAction 'silentlycontinue') {
  Stop-Process -ProcessName explorer -Force
}

# Download Olaf Hartongs Sysmon config
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Olaf Hartong's Sysmon config..."
(New-Object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml', "$sysmonConfigPath")
# Alternative: Download SwiftOnSecurity's Sysmon config
# Write-Host "Downloading SwiftOnSecurity's Sysmon config..."
# (New-Object System.Net.WebClient).DownloadFile('https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml', "$sysmonConfigPath")

# Start Sysmon
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Starting Sysmon..."
Start-Process -FilePath "$sysmonDir\Sysmon64.exe" -ArgumentList "-accepteula -i $sysmonConfigPath"
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Verifying that the Sysmon service is running..."
Start-Sleep 5 # Give the service time to start
If ((Get-Service -name Sysmon64).Status -ne "Running")
{
  throw "The Sysmon service did not start successfully"
}

# Make the event log channel readable. For some reason this doesn't work in the GPO and only works when run manually.
wevtutil sl Microsoft-Windows-Sysmon/Operational "/ca:O:BAG:SYD:(A;;0x5;;;BA)(A;;0x1;;;S-1-5-20)(A;;0x1;;;S-1-5-32-573)"
