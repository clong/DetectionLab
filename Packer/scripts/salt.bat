if not exist "C:\Windows\Temp\salt64.exe" (
  powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://docs.saltstack.com/downloads/Salt-Minion-2014.1.3-1-AMD64-Setup.exe', 'C:\Windows\Temp\salt64.exe')" <NUL
)

:: http://docs.saltstack.com/en/latest/topics/installation/windows.html
c:\windows\temp\salt64.exe /S
:: /master=<yoursaltmaster> /minion-name=<thisminionname>

<nul set /p ".=;C:\salt" >> C:\Windows\Temp\PATH
set /p PATH=<C:\Windows\Temp\PATH
setx PATH "%PATH%" /m
