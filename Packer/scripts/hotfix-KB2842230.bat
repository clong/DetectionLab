:: Windows 8 / Windows 2012 require KB2842230 hotfix
:: The Windows Remote Management (WinRM) service does not use the customized value of the MaxMemoryPerShellMB quota.
:: Instead, the WinRM service uses the default value, which is 150 MB. 
:: http://hotfixv4.microsoft.com/Windows%208%20RTM/nosp/Fix452763/9200/free/463941_intl_x64_zip.exe

@echo off
set hotfix="C:\Windows\Temp\Windows8-RT-KB2842230-x64.msu"
if not exist %hotfix% goto :eof

:: get windows version
for /f "tokens=2 delims=[]" %%G in ('ver') do (set _version=%%G) 
for /f "tokens=2,3,4 delims=. " %%G in ('echo %_version%') do (set _major=%%G& set _minor=%%H& set _build=%%I) 

:: 6.2 or 6.3
if %_major% neq 6 goto :eof
if %_minor% lss 2 goto :eof
if %_minor% gtr 3 goto :eof

@echo on
start /wait wusa "%hotfix%" /quiet /norestart