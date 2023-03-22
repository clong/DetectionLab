Write-Output "Running Autohotkey uninstaller"
$toolsPath = Split-Path $MyInvocation.MyCommand.Definition
$ahkScript = "$toolsPath\winpcapInstall.ahk"
AutoHotkey $ahkScript $packageArgs.fileFullPath
