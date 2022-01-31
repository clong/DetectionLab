# Purpose: Installs Mimikatz and Powersploit into c:\Tools\Mimikatz. Used to install redteam related tooling.

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing Red Team Tooling..."
$hostname = $(hostname)

# Disabling the progress bar speeds up IWR https://github.com/PowerShell/PowerShell/issues/2138
$ProgressPreference = 'SilentlyContinue'
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Windows Defender should be disabled already by O&O ShutUp10 and the GPO
If ($hostname -eq "win10" -And (Get-Service -Name WinDefend).StartType -ne 'Disabled' ) {
  # Adding Defender exclusions just in case
  Set-MpPreference -ExclusionPath "C:\Tools"
  Add-MpPreference -ExclusionPath "C:\Users\vagrant\AppData\Local\Temp"

  . c:\vagrant\scripts\Invoke-CommandAs.ps1
  Invoke-CommandAs 'NT SERVICE\TrustedInstaller' {
    Set-Service WinDefend -StartupType Disabled
    Stop-Service WinDefend
  }
}

# Windows Defender should be disabled by the GPO or uninstalled already, but we'll keep this just in case
If ($hostname -ne "win10" -And (Get-Service -Name WinDefend -ErrorAction SilentlyContinue).status -eq 'Running') {
  # Uninstalling Windows Defender (https://github.com/StefanScherer/packer-windows/issues/201)
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Uninstalling Windows Defender..."
  Try {
    Uninstall-WindowsFeature Windows-Defender -ErrorAction Stop
    Uninstall-WindowsFeature Windows-Defender-Features -ErrorAction Stop
  } Catch {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Windows Defender did not uninstall successfully..."
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) We'll try again during install-red-team.ps1"
  }
} Else  {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Windows Defender has already been disabled or uninstalled."
}

# Purpose: Downloads and unzips a copy of the latest Mimikatz trunk
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Determining latest release of Mimikatz..."
$tag = (Invoke-WebRequest "https://api.github.com/repos/gentilkiwi/mimikatz/releases" -UseBasicParsing | ConvertFrom-Json)[0].tag_name
$mimikatzDownloadUrl = "https://github.com/gentilkiwi/mimikatz/releases/download/$tag/mimikatz_trunk.zip"
$mimikatzRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\mimikatz_trunk.zip'
If (-not (Test-Path $mimikatzRepoPath)) {
  Invoke-WebRequest -Uri "$mimikatzDownloadUrl" -OutFile $mimikatzRepoPath
  Expand-Archive -path "$mimikatzRepoPath" -destinationpath 'c:\Tools\Mimikatz' -Force
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Mimikatz was already installed. Moving On."
}

# Download and unzip a copy of PowerSploit
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Powersploit..."
$powersploitDownloadUrl = "https://github.com/PowerShellMafia/PowerSploit/archive/dev.zip"
$powersploitRepoPath = "C:\Users\vagrant\AppData\Local\Temp\powersploit.zip"
If (-not (Test-Path $powersploitRepoPath)) {
  Invoke-WebRequest -Uri "$powersploitDownloadUrl" -OutFile $powersploitRepoPath
  Expand-Archive -path "$powersploitRepoPath" -destinationpath 'c:\Tools\PowerSploit' -Force
  Copy-Item "c:\Tools\PowerSploit\PowerSploit-dev\*" "$Env:windir\System32\WindowsPowerShell\v1.0\Modules" -Recurse -Force
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) PowerSploit was already installed. Moving On."
}

# Download and unzip a copy of BadBlood
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading BadBlood..."
$badbloodDownloadUrl = "https://github.com/davidprowe/BadBlood/archive/master.zip"
$badbloodRepoPath = "C:\Users\vagrant\AppData\Local\Temp\badblood.zip"
If (-not (Test-Path $badbloodRepoPath)) {
  Invoke-WebRequest -Uri "$badbloodDownloadUrl" -OutFile "$badbloodRepoPath"
  Expand-Archive -path "$badbloodRepoPath" -destinationpath 'c:\Tools\BadBlood' -Force
  # Lower the number of default users to be created by BadBlood
  $invokeBadBloodPath = "c:\Tools\BadBlood\BadBlood-master\Invoke-BadBlood.ps1"
  ((Get-Content -path $invokeBadBloodPath -Raw) -replace '1000..5000','500..1500') | Set-Content -Path $invokeBadBloodPath
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) BadBlood was already installed. Moving On."
}

# Download and install Invoke-AtomicRedTeam
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Invoke-AtomicRedTeam and atomic tests..."
If (-not (Test-Path "C:\Tools\AtomicRedTeam")) {
  Install-PackageProvider -Name NuGet -Force
  Install-Module -Name powershell-yaml -Force
  IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing);
  Install-AtomicRedTeam -getAtomics -InstallPath "c:\Tools\AtomicRedTeam"
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Updating Profile.ps1 to import the Invoke-AtomicRedTeam module..."
  Add-Content -Path C:\Windows\System32\WindowsPowerShell\v1.0\Profile.ps1 'Import-Module "C:\Tools\AtomicRedTeam\invoke-atomicredteam\Invoke-AtomicRedTeam.psd1" -Force
$PSDefaultParameterValues = @{"Invoke-AtomicTest:PathToAtomicsFolder"="C:\Tools\AtomicRedTeam\atomics"}' -Force
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Invoke-AtomicRedTeam was already installed. Moving On."
}

# Purpose: Downloads the latest release of PurpleSharpNewtonsoft.Json.dll
If (-not (Test-Path "c:\Tools\PurpleSharp")) {
  New-Item -Path "c:\Tools\" -Name "PurpleSharp" -ItemType "directory"
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) PurpleSharp folder already exists. Moving On."
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Determining latest release of Purplesharp..."
$tag = (Invoke-WebRequest "https://api.github.com/repos/mvelazc0/PurpleSharp/releases" -UseBasicParsing | ConvertFrom-Json)[0].tag_name
$purplesharpDownloadUrl = "https://github.com/mvelazc0/PurpleSharp/releases/download/$tag/PurpleSharp_x64.exe"
If (-not (Test-Path "c:\Tools\PurpleSharp\PurpleSharp.exe")) {
  Invoke-WebRequest -Uri $purplesharpDownloadUrl -OutFile "c:\Tools\PurpleSharp\PurpleSharp.exe"
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) PurpleSharp was already installed. Moving On."
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Red Team tooling installation complete!"
