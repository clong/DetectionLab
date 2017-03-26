@echo off
:: Windows 7 / Windows 2008 R2 require KB2552055 hotfix
:: This fixes a problem with wrong exitcode 0 instead of custom exitcode in PowerShell 2.0
setlocal
if defined ProgramFiles(x86) (
  set link=http://hotfixv4.microsoft.com/Windows%%207/Windows%%20Server2008%%20R2%%20SP1/sp2/Fix373932/7600/free/438167_intl_x64_zip.exe
  set msufilename=%TEMP%\Windows6.1-KB2552055-x64.msu
) else (
  set link=http://hotfixv4.microsoft.com/Windows%%207/Windows%%20Server2008%%20R2%%20SP1/sp2/Fix373932/7600/free/438164_intl_i386_zip.exe
  set msufilename=%TEMP%\Windows6.1-KB2552055-x86.msu
)
set zipfilename=%TEMP%\KB2552055.zip

echo Downloading Hotfix 2552055
powershell -Command "(New-Object System.Net.WebClient).DownloadFile('%link%', '%zipfilename%')" <NUL
echo Extracting Hotfix 2552055
powershell -Command "(New-Object -com Shell.Application).NameSpace('%TEMP%').CopyHere((New-Object -Com Shell.Application).NameSpace('%zipfilename%').items())" <NUL
echo Installing Hotfix 2552055
wusa %msufilename% /quiet /norestart

echo Cleanup Hotfix temp files
del /Q %msufilename%
del /Q %zipfilename%
