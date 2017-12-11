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

# Purpose: Downloads and unzips a copy of the Palantir osquery Github Repo. These configs are added to the Fleet server in bootstrap.sh.
$mimikatzRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\osquery-Master.zip'
Invoke-WebRequest -Uri "https://github.com/gentilkiwi/mimikatz/releases/download/2.1.1-20171203/mimikatz_trunk.zip" -OutFile $mimikatzRepoPath
Expand-Archive -path "$mimikatzRepoPath" -destinationpath 'c:\Tools\Mimikatz' -Force
