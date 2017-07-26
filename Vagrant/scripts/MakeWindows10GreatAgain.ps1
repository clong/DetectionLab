# Import the registry keys
Write-Host "Importing registry keys..."
regedit /s c:\vagrant\resources\MakeWindows10GreatAgain.reg

# Remove OneDrive from the System
taskkill /f /im OneDrive.exe
%SystemRoot%\SysWOW64\OneDriveSetup.exe /uninstall
