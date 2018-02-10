# Purpose: Installs chocolatey package manager, then installs custom utilities from Choco and adds syntax highlighting for Powershell, Batch, and Docker. Also installs Mimikatz into c:\Tools\Mimikatz.

If (-not (Test-Path "C:\ProgramData\chocolatey")) {
  Write-Host "Installing Chocolatey"
  iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
}
else {
  Write-Host "Chocolatey is already installed."
}

Write-Host "Installing atom, Notepad++, Chrome, WinRar, and Mimikatz."
choco install -y atom
choco install -y NotepadPlusPlus
choco install -y GoogleChrome
choco install -y WinRar
Write-Host $env:LOCALAPPDATA
$env:PATH="$env:PATH;$env:LOCALAPPDATA\atom\bin"
apm install language-powershell
apm install language-batch
apm install language-docker

# Disable Windows Defender realtime scanning before downloading Mimikatz
If ($env:computername -eq "WIN10") {
  set-MpPreference -DisableRealtimeMonitoring $true
  Set-MpPreference -ExclusionPath C:\commander.exe, C:\Tools
}

# Purpose: Downloads and unzips a copy of the latest Mimikatz trunk
Write-Host "Determining latest release of Mimikatz..."
$tag = (Invoke-WebRequest "https://api.github.com/repos/gentilkiwi/mimikatz/releases" -UseBasicParsing | ConvertFrom-Json)[0].tag_name
$mimikatzDownloadUrl = "https://github.com/gentilkiwi/mimikatz/releases/download/$tag/mimikatz_trunk.zip"
$mimikatzRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\mimikatz_trunk.zip'
Invoke-WebRequest -Uri "$mimikatzDownloadUrl" -OutFile $mimikatzRepoPath
Expand-Archive -path "$mimikatzRepoPath" -destinationpath 'c:\Tools\Mimikatz' -Force
