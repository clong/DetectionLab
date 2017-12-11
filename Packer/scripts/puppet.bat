if not exist "C:\Windows\Temp\puppet.msi" (
  powershell -Command "(New-Object System.Net.WebClient).DownloadFile('http://downloads.puppetlabs.com/windows/puppet-3.6.2.msi', 'C:\Windows\Temp\puppet.msi')" <NUL
)

:: http://docs.puppetlabs.com/pe/latest/install_windows.html
msiexec /qn /i C:\Windows\Temp\puppet.msi /log C:\Windows\Temp\puppet.log

<nul set /p ".=;C:\Program Files (x86)\Puppet Labs\Puppet\bin" >> C:\Windows\Temp\PATH
set /p PATH=<C:\Windows\Temp\PATH
setx PATH "%PATH%" /m
