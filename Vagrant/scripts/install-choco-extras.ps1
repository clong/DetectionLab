# Purpose: Install additional packages from Chocolatey.

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing additional Choco packages..."

If (-not (Test-Path "C:\ProgramData\chocolatey")) {
  Write-Host "Installing Chocolatey"
  iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
} else {
  Write-Host "Chocolatey is already installed."
}

Write-Host "Installing Chocolatey extras..."
choco install -y --limit-output --no-progress wireshark
choco install -y --limit-output --no-progress winpcap

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Choco addons complete!"
