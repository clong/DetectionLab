rem https://connect.microsoft.com/PowerShell/feedback/details/1609288/pin-to-taskbar-no-longer-working-in-windows-10
copy "A:\WindowsPowerShell.lnk" "%TEMP%\Windows PowerShell.lnk"
A:\PinTo10.exe /PTFOL01:'%TEMP%' /PTFILE01:'Windows PowerShell.lnk'
exit /b 0
