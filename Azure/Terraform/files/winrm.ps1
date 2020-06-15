powershell.exe -c "Set-NetConnectionProfile -InterfaceAlias Ethernet -NetworkCategory Private"
Enable-PSRemoting -Force
winrm quickconfig -q
winrm quickconfig -transport:http
powershell.exe -c "winrm set winrm/config '@{MaxTimeoutms=\`"1800000\`"}'"
powershell.exe -c "winrm set winrm/config/winrs '@{MaxMemoryPerShellMB=\`"800\`"}'"
powershell.exe -c "winrm set winrm/config/service '@{AllowUnencrypted=\`"true\`"}'"
powershell.exe -c "winrm set winrm/config/service/auth '@{Basic=\`"true\`"}'"
powershell.exe -c "winrm set winrm/config/client/auth '@{Basic=\`"true\`"}'"
powershell.exe -c "winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port=\`"5985\`"}'"
netsh advfirewall firewall set rule group="Windows Remote Administration" new enable=yes
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new enable=yes action=allow remoteip=any
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce /v StartWinRM /t REG_SZ /f /d "cmd.exe /c 'sc config winrm start= auto & sc start winrm'"
Restart-Service winrm
netsh advfirewall firewall add rule name="Port 5985" dir=in action=allow protocol=TCP localport=5985 
 
