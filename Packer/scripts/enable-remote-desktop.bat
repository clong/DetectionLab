rem from http://networkerslog.blogspot.de/2013/09/how-to-enable-remote-desktop-remotely.html

rem 1) Enable Remote Desktop
rem set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server" /v "fDenyTSConnections" /t REG_DWORD /d 0 /f

rem 2) Allow incoming RDP on firewall
rem Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes

rem 3) Enable secure RDP authentication
rem set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 0   
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v "UserAuthentication" /t REG_DWORD /d 0 /f

