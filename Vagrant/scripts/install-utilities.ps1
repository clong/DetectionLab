# Purpose: Installs chocolatey package manager, then installs custom utilities from Choco.

If (-not (Test-Path "C:\ProgramData\chocolatey")) {
  Write-Host "Installing Chocolatey"
  iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
} else {
  Write-Host "Chocolatey is already installed."
}

Write-Host "Installing utilities..."
If ($(hostname) -eq "win10") {
  # Because the Windows10 start menu sucks
  choco install -y classic-shell -installArgs ADDLOCAL=ClassicStartMenu
  reg import "c:\vagrant\resources\windows\classic_shell_win7.reg"
}
choco install -y NotepadPlusPlus
choco install -y GoogleChrome
choco install -y WinRar

Write-Host "Utilties installation complete!"
