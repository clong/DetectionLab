$ProgressPreference = 'SilentlyContinue'

Set-ExecutionPolicy Bypass -scope Process
New-Item -Type Directory -Path "$($env:ProgramFiles)\docker"
wget -outfile $env:TEMP\docker-17-03-0-ee.zip "https://dockermsft.blob.core.windows.net/dockercontainer/docker-17-03-0-ee.zip"
Expand-Archive -Path $env:TEMP\docker-17-03-0-ee.zip -DestinationPath $env:TEMP -Force
copy $env:TEMP\docker\*.exe $env:ProgramFiles\docker
Remove-Item $env:TEMP\docker-17-03-0-ee.zip
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$($env:ProgramFiles)\docker", [EnvironmentVariableTarget]::Machine)
$env:Path = $env:Path + ";$($env:ProgramFiles)\docker"
. dockerd --register-service -H npipe:// -H 0.0.0.0:2375 -G docker
Start-Service docker
