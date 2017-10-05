# Check to see if Anniversary Update is installed
if ([System.Environment]::OSVersion.Version.Build -lt 14393) {
  Write-Host "Anniversary Update is required and not installed. Exiting."
  Exit
}

# Import the registry keys
Write-Host "Importing registry keys..."
regedit /s c:\vagrant\resources\MakeWindows10GreatAgain.reg

# Install Powershell Help items
Update-Help

# Remove OneDrive from the System
taskkill /f /im OneDrive.exe
c:\Windows\SysWOW64\OneDriveSetup.exe /uninstall

# Disable SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Confirm:$false

# Install Linux Subsystem
Write-Host "Installing the Linux Subsystem..."
Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux"
