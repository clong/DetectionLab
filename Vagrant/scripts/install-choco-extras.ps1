# Purpose: Install additional packages from Chocolatey.

Write-Host "Installing additional Choco packages..."

If (-not (Test-Path "C:\ProgramData\chocolatey")) {
  Write-Host "Installing Chocolatey"
  iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
} else {
  Write-Host "Chocolatey is already installed."
}

Write-Host "Installing Chocolatey extras..."
choco install -y wireshark
choco install -y winpcap

Write-Host "Choco addons complete!"
