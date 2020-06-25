# Purpose: Installs Mimikatz and Powersploit into c:\Tools\Mimikatz. Used to install redteam related tooling.

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing Red Team Tooling..."
$hostname = $(hostname)

# Windows Defender should be disabled already by O&O ShutUp10 and the GPO
If ($hostname -eq "win10") {
  # Adding Defender exclusions just in case
  Set-MpPreference -ExclusionPath "C:\Tools"
  Add-MpPreference -ExclusionPath "C:\Users\vagrant\AppData\Local\Temp"
  Set-MpPreference -DisableRealtimeMonitoring $true
}

# Windows Defender should be disabled already by the GPO, sometimes it doesnt work
If ($hostname -ne "win10" -And (Get-Service -Name WinDefend -ErrorAction SilentlyContinue).status -eq 'Running') {
  # Uninstalling Windows Defender (https://github.com/StefanScherer/packer-windows/issues/201)
  Uninstall-WindowsFeature Windows-Defender
  Uninstall-WindowsFeature Windows-Defender-Features
}

# Purpose: Downloads and unzips a copy of the latest Mimikatz trunk
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Determining latest release of Mimikatz..."
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tag = (Invoke-WebRequest "https://api.github.com/repos/gentilkiwi/mimikatz/releases" -UseBasicParsing | ConvertFrom-Json)[0].tag_name
$mimikatzDownloadUrl = "https://github.com/gentilkiwi/mimikatz/releases/download/$tag/mimikatz_trunk.zip"
$mimikatzRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\mimikatz_trunk.zip'
if (-not (Test-Path $mimikatzRepoPath)) {
  Invoke-WebRequest -Uri "$mimikatzDownloadUrl" -OutFile $mimikatzRepoPath
  Expand-Archive -path "$mimikatzRepoPath" -destinationpath 'c:\Tools\Mimikatz' -Force
}
else {
  Write-Host "Mimikatz was already installed. Moving On."
}

# Download and unzip a copy of PowerSploit
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Powersploit..."
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$powersploitDownloadUrl = "https://github.com/PowerShellMafia/PowerSploit/archive/dev.zip"
$powersploitRepoPath = "C:\Users\vagrant\AppData\Local\Temp\powersploit.zip"
if (-not (Test-Path $powersploitRepoPath)) {
  Invoke-WebRequest -Uri "$powersploitDownloadUrl" -OutFile $powersploitRepoPath
  Expand-Archive -path "$powersploitRepoPath" -destinationpath 'c:\Tools\PowerSploit' -Force
  Copy-Item "c:\Tools\PowerSploit\PowerSploit-dev\*" "$Env:windir\System32\WindowsPowerShell\v1.0\Modules" -Recurse -Force
}
else {
  Write-Host "PowerSploit was already installed. Moving On."
}

# Download and unzip a copy of Atomic Red Team
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Atomic Red Team..."
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$atomicRedTeamDownloadUrl = "https://github.com/redcanaryco/atomic-red-team/archive/master.zip"
$atomicRedTeamRepoPath = "C:\Users\vagrant\AppData\Local\Temp\atomic_red_team.zip"
if (-not (Test-Path $atomicRedTeamRepoPath)) {
  Invoke-WebRequest -Uri "$atomicRedTeamDownloadUrl" -OutFile "$atomicRedTeamRepoPath"
  Expand-Archive -path "$atomicRedTeamRepoPath" -destinationpath 'c:\Tools\Atomic Red Team' -Force
}
else {
  Write-Host "Atomic Red Team was already installed. Moving On."
}

# Download and unzip a copy of BadBlood
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading BadBlood..."
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$badbloodDownloadUrl = "https://github.com/davidprowe/BadBlood/archive/master.zip"
$badbloodRepoPath = "C:\Users\vagrant\AppData\Local\Temp\badblood.zip"
if (-not (Test-Path $badbloodRepoPath)) {
  Invoke-WebRequest -Uri "$badbloodDownloadUrl" -OutFile "$badbloodRepoPath"
  Expand-Archive -path "$badbloodRepoPath" -destinationpath 'c:\Tools\BadBlood' -Force
  # Lower the number of default users to be created by BadBlood
  $invokeBadBloodPath = "c:\Tools\BadBlood\BadBlood-master\Invoke-BadBlood.ps1"
  ((Get-Content -path $invokeBadBloodPath -Raw) -replace '1000..5000','500..1500') | Set-Content -Path $invokeBadBloodPath
}
else {
  Write-Host "BadBlood was already installed. Moving On."
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Red Team tooling installation complete!"

