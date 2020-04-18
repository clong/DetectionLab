# Purpose: Installs chocolatey package manager, then installs custom utilities from Choco.

If (-not (Test-Path "C:\ProgramData\chocolatey")) {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Write-Host "Installing Chocolatey"
  iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
} else {
  Write-Host "Chocolatey is already installed."
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing utilities..."
If ($(hostname) -eq "win10") {
  # Because the Windows10 start menu sucks
  choco install -y --limit-output --no-progress classic-shell -installArgs ADDLOCAL=ClassicStartMenu
  & "C:\Program Files\Classic Shell\ClassicStartMenu.exe" "-xml" "c:\vagrant\resources\windows\MenuSettings.xml"
  regedit /s c:\vagrant\resources\windows\MenuStyle_Default_Win7.reg
}
choco install -y --limit-output --no-progress NotepadPlusPlus GoogleChrome WinRar

Write-Host "Utilties installation complete!"
