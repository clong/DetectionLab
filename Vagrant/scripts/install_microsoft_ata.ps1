# Purpose: Downloads and installs a copy of the Palantir WEF Github Repo. This includes WEF subscriptions and custom WEF channels.

Write-Host "Downloading Microsoft ATA 1.9..."

Invoke-WebRequest -Uri "http://download.microsoft.com/download/4/9/1/491394D1-3F28-4261-ABC6-C836A301290E/ATA1.9.iso" -OutFile $env:temp\ATA1.9.iso

$Mount = Mount-DiskImage -ImagePath $env:temp\ATA1.9.iso -StorageType ISO -Access ReadOnly -PassThru
$Volume = $Mount | Get-Volume
Set-Location ($Volume.DriveLetter + ":")

& '.\Microsoft ATA Center Setup.exe' /q --LicenseAccepted NetFrameworkCommandLineArguments="/q" --EnableMicrosoftUpdate