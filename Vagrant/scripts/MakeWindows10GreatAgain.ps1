# Import the registry keys
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Making Windows 10 Great again"
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Importing registry keys..."
regedit /s c:\vagrant\scripts\MakeWindows10GreatAgain.reg

# Remove OneDrive from the System
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Removing OneDrive..."
$onedrive = Get-Process onedrive -ErrorAction SilentlyContinue
if ($onedrive) {
  taskkill /f /im OneDrive.exe
}
c:\Windows\SysWOW64\OneDriveSetup.exe /uninstall

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Disabling automatic screen turnoff in order to prevent screen locking..."
powercfg -change -monitor-timeout-ac 0
powercfg -change -standby-timeout-ac 0
powercfg -change -hibernate-timeout-ac 0

# Download and install ShutUp10
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading ShutUp10..."
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
# Disabling the progress bar speeds up IWR https://github.com/PowerShell/PowerShell/issues/2138
$ProgressPreference = 'SilentlyContinue'
$shutUp10DownloadUrl = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
$shutUp10RepoPath = "C:\Users\vagrant\AppData\Local\Temp\OOSU10.exe"
if (-not (Test-Path $shutUp10RepoPath)) {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing ShutUp10 and disabling Windows Defender"
  Invoke-WebRequest -Uri "$shutUp10DownloadUrl" -OutFile $shutUp10RepoPath
  . $shutUp10RepoPath c:\vagrant\resources\windows\shutup10.cfg /quiet /force
} else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) ShutUp10 was already installed. Moving On."
}

# Remove the Edge shortcut from the Desktop
$lnkPath = "c:\Users\vagrant\Desktop\Microsoft Edge.lnk"
if (Test-Path $lnkPath) { Remove-Item $lnkPath }
