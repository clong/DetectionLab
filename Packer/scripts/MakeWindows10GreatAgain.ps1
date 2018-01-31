# Import the registry keys
Write-Host "Making Windows 10 Great again"
Write-Host "Importing registry keys..."
regedit /s a:\MakeWindows10GreatAgain.reg

# Install Powershell Help items
Write-Host "Updating Powershell Help Library..."
Update-Help

# Remove OneDrive from the System
Write-Host "Removing OneDrive..."
$onedrive = Get-Process onedrive -ErrorAction SilentlyContinue
if ($onedrive) {
  taskkill /f /im OneDrive.exe
}
c:\Windows\SysWOW64\OneDriveSetup.exe /uninstall
