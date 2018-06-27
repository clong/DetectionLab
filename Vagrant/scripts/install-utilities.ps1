# Purpose: Installs chocolatey package manager, then installs custom utilities from Choco and adds syntax highlighting for Powershell, Batch, and Docker. Also installs Mimikatz into c:\Tools\Mimikatz.

If (-not (Test-Path "C:\ProgramData\chocolatey")) {
  Write-Host "Installing Chocolatey"
  iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
} else {
  Write-Host "Chocolatey is already installed."
}

Write-Host "Installing Notepad++, Chrome, WinRar, PowerSploit and Mimikatz."
If ($(hostname) -eq "win10") {
  # Because the Windows10 start menu sucks
  choco install -y classic-shell -installArgs ADDLOCAL=ClassicStartMenu
}
choco install -y NotepadPlusPlus
choco install -y GoogleChrome
choco install -y WinRar

# Disable Windows Defender realtime scanning before downloading Mimikatz
If ($env:computername -eq "win10") {
  If (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender")
  {
    Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Recurse -Force
  }
  gpupdate /force | Out-String
  Set-MpPreference -ExclusionPath C:\commander.exe, C:\Tools
  set-MpPreference -DisableRealtimeMonitoring $true

}

# Purpose: Downloads and unzips a copy of the latest Mimikatz trunk
Write-Host "Determining latest release of Mimikatz..."
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tag = (Invoke-WebRequest "https://api.github.com/repos/gentilkiwi/mimikatz/releases" -UseBasicParsing | ConvertFrom-Json)[0].tag_name
$mimikatzDownloadUrl = "https://github.com/gentilkiwi/mimikatz/releases/download/$tag/mimikatz_trunk.zip"
$mimikatzRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\mimikatz_trunk.zip'
if (-not (Test-Path $mimikatzRepoPath))
{
  Invoke-WebRequest -Uri "$mimikatzDownloadUrl" -OutFile $mimikatzRepoPath
  Expand-Archive -path "$mimikatzRepoPath" -destinationpath 'c:\Tools\Mimikatz' -Force
}
else
{
  Write-Host "Mimikatz was already installed. Moving On."
}

# Download and unzip a copy of PowerSploit
Write-Host "Downloading Powersploit..."
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$powersploitDownloadUrl = "https://github.com/PowerShellMafia/PowerSploit/archive/master.zip"
$powersploitRepoPath = "C:\Users\vagrant\AppData\Local\Temp\powersploit.zip"
if (-not (Test-Path $powersploitRepoPath)) {
  Invoke-WebRequest -Uri "$powersploitDownloadUrl" -OutFile $powersploitRepoPath
  Expand-Archive -path "$powersploitRepoPath" -destinationpath 'c:\Tools\PowerSploit' -Force
  Copy-Item "c:\Tools\PowerSploit\PowerSploit-master\*" "$Env:windir\System32\WindowsPowerShell\v1.0\Modules" -Recurse -Force
} else {
  Write-Host "PowerSploit was already installed. Moving On."
}

Write-Host "Utilties installation complete!"
