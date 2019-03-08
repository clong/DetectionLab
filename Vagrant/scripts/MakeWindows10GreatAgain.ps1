# Import the registry keys
Write-Host "Making Windows 10 Great again"
Write-Host "Importing registry keys..."
regedit /s a:\MakeWindows10GreatAgain.reg

# Remove OneDrive from the System
Write-Host "Removing OneDrive..."
$onedrive = Get-Process onedrive -ErrorAction SilentlyContinue
if ($onedrive) {
  taskkill /f /im OneDrive.exe
}
c:\Windows\SysWOW64\OneDriveSetup.exe /uninstall

Write-Host "Running Update-Help..."
Update-Help -Force -ErrorAction SilentlyContinue

Write-Host "Removing Microsoft Store and Edge shortcuts from the taskbar..."
$appname = "Microsoft Edge"
((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -eq $appname}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from taskbar'} | %{$_.DoIt(); $exec = $true}
$appname = "Microsoft Store"
((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -eq $appname}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from taskbar'} | %{$_.DoIt(); $exec = $true}
$appname = "Mail"
((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | ?{$_.Name -eq $appname}).Verbs() | ?{$_.Name.replace('&','') -match 'Unpin from taskbar'} | %{$_.DoIt(); $exec = $true}

Write-Host "Disabling automatic screen turnoff in order to prevent screen locking..."
powercfg -change -monitor-timeout-ac 0
powercfg -change -standby-timeout-ac 0
powercfg -change -hibernate-timeout-ac 0

# Download and install ShutUp10
Write-Host "Downloading ShutUp10..."
[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
$shutUp10DownloadUrl = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
$shutUp10RepoPath = "C:\Users\vagrant\AppData\Local\Temp\OOSU10.exe"
if (-not (Test-Path $shutUp10RepoPath)) {
  Invoke-WebRequest -Uri "$shutUp10DownloadUrl" -OutFile $shutUp10RepoPath
  . $shutUp10RepoPath c:\vagrant\resources\windows\shutup10.cfg /quiet /force
} else {
  Write-Host "ShutUp10 was already installed. Moving On."
}
