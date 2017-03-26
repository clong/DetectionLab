if (!(Test-Path 'c:\Program Files\sysinternals')) {
  New-Item -Path 'c:\Program Files\sysinternals' -type directory -Force -ErrorAction SilentlyContinue
}
if (!(Test-Path 'c:\Program Files\sysinternals\bginfo.exe')) {
  (New-Object Net.WebClient).DownloadFile('http://live.sysinternals.com/bginfo.exe', 'c:\Program Files\sysinternals\bginfo.exe')
}
$vbsScript = @'
WScript.Sleep 15000
Dim objShell
Set objShell = WScript.CreateObject( "WScript.Shell" )
objShell.Run("""c:\Program Files\sysinternals\bginfo.exe"" /accepteula ""c:\Program Files\sysinternals\bginfo.bgi"" /silent /timer:0")
'@

$vbsScript | Out-File 'c:\Program Files\sysinternals\bginfo.vbs'

Copy-Item "C:\vagrant\scripts\bginfo.bgi" 'c:\Program Files\sysinternals\bginfo.bgi'

Set-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -Name bginfo -Value 'wscript "c:\Program Files\sysinternals\bginfo.vbs"'

