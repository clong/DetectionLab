if not exist "C:\Windows\Temp\puppet.msi" (
  powershell -Command "(New-Object System.Net.WebClient).DownloadFile('http://pm.puppetlabs.com/puppet-enterprise/3.0.1/puppet-enterprise-3.0.1.msi', 'C:\Windows\Temp\puppet.msi')" <NUL
)

:: http://docs.puppetlabs.com/pe/latest/install_windows.html
msiexec /qn /i C:\Windows\Temp\puppet.msi /log C:\Windows\Temp\puppet.log

<nul set /p ".=;C:\Program Files (x86)\Puppet Labs\Puppet Enterprise\bin" >> C:\Windows\Temp\PATH
set /p PATH=<C:\Windows\Temp\PATH
setx PATH "%PATH%" /m