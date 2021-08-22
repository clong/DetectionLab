# Source: https://docs.microsoft.com/en-us/troubleshoot/azure/virtual-machines/credssp-encryption-oracle-remediation

$source = "http://download.windowsupdate.com/d/msdownload/update/software/secu/2018/05/windows10.0-kb4103723-x64_2adf2ea2d09b3052d241c40ba55e89741121e07e.msu"
$destination = "$env:TEMP\windows10.0-kb4103723-x64_2adf2ea2d09b3052d241c40ba55e89741121e07e.msu"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($source,$destination)
expand -F:* $destination $env:TEMP
dism /NoRestart /ONLINE /add-package /packagepath:"$env:TEMP\Windows10.0-KB4103723-x64.cab"

REG ADD "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System\CredSSP\Parameters" /v AllowEncryptionOracle /t REG_DWORD /d 2