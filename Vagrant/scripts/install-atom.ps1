choco install -y atom
Write-Host $env:LOCALAPPDATA
$env:PATH="$env:PATH;$env:LOCALAPPDATA\atom\bin"
apm install language-powershell
apm install language-batch
apm install language-docker
