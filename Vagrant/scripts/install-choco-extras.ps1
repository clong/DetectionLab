# Purpose: Install additional packages from Chocolatey.

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing additional Choco packages..."

If (-not (Test-Path "C:\ProgramData\chocolatey")) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing Chocolatey"
  iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
} else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Chocolatey is already installed."
}

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing Chocolatey extras..."
choco install -y --limit-output --no-progress wireshark
choco install -y --limit-output --no-progress --version "1.1.36.02" autohotkey.portable

cd choco-winpcap
choco pack WinPcap.nuspec
choco install -y --limit-output --no-progress winpcap --source .

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Choco addons complete!"
