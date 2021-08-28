<!-- :
@setlocal EnableDelayedExpansion EnableExtensions
@for %%i in (%~dp0\_packer_config*.cmd) do @call "%%~i"
@if defined PACKER_DEBUG (@echo on) else (@echo off)

echo ==^> Disabling Windows Updates

:: stop the service and disable it
SC stop wuauserv
SC config wuauserv start= disabled

:: Notify before download
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 2 /f

:: turn the whole thing off
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate" /v DisableWindowsUpdateAccess /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f

:: disable the update prompt scheduled tasks
schtasks.exe /change /tn "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker_Display" /disable
schtasks.exe /change /tn "\Microsoft\Windows\UpdateOrchestrator\MusUx_UpdateInterval" /disable
schtasks.exe /change /tn "\Microsoft\Windows\WindowsUpdate\sih" /disable

exit /b