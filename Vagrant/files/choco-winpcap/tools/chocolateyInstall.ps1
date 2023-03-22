$ErrorActionPreference = 'Stop'

$packageArgs = @{
  packageName    = 'WinPcap'
  fileFullPath   = "$(Get-PackageCacheLocation)\WinPcapInstall.exe"
  url            = 'https://www.winpcap.org/install/bin/WinPcap_4_1_3.exe'
  checksum       = 'fc4623b113a1f603c0d9ad5f83130bd6de1c62b973be9892305132389c8588de'
  checksumType   = 'sha256'
}
Get-ChocolateyWebFile @packageArgs

Write-Output "Running Autohotkey installer"
$toolsPath = Split-Path $MyInvocation.MyCommand.Definition
$ahkScript = "$toolsPath\winpcapInstall.ahk"
AutoHotkey $ahkScript $packageArgs.fileFullPath
