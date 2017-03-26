if not exist "C:\Windows\Temp\chef.msi" (
  powershell -Command "(New-Object System.Net.WebClient).DownloadFile('http://www.getchef.com/chef/install.msi', 'C:\Windows\Temp\chef.msi')" <NUL
)

msiexec /qb /i C:\Windows\Temp\chef.msi
powershell -Command "Start-Sleep 1" <NUL