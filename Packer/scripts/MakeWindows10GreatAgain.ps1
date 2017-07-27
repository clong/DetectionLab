# Import the registry keys
Write-Host "Importing registry keys..."
regedit /s .\MakeWindows10GreatAgain.reg

# Remove OneDrive from the System
taskkill /f /im OneDrive.exe
c:\windows\SysWOW64\OneDriveSetup.exe /uninstall
