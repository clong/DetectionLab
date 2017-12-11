powershell -NoProfile -ExecutionPolicy unrestricted -Command "(New-Object System.Net.WebClient).DownloadFile('http://download.microsoft.com/download/5/6/2/562A10F9-C9F4-4313-A044-9C94E0A8FAC8/dotNetFx40_Client_x86_x64.exe', 'C:\Windows\Temp\dotNetFx40.exe')" <NUL
C:\Windows\Temp\dotNetFx40.exe /q /norestart /repair
