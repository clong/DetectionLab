# Purpose: Installs velociraptor on the host

param (
  [switch]$Update
)

# Add a hosts entry to avoid DNS issues
If (Select-String -Path "c:\windows\system32\drivers\etc\hosts" -Pattern "logger") {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Hosts file already updated. Moving on."
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Adding logger to the hosts file"
  Add-Content "c:\windows\system32\drivers\etc\hosts" "        192.168.56.105    logger"
}

# Downloads and install the latest Velociraptor release
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Determining latest release of Velociraptor..."
# GitHub requires TLS 1.2 as of 2/27
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Disabling the progress bar speeds up IWR https://github.com/PowerShell/PowerShell/issues/2138
$ProgressPreference = 'SilentlyContinue'
$velociraptorDownloadUrl = "https://github.com" + ((Invoke-WebRequest "https://github.com/Velocidex/velociraptor/releases/latest" -UseBasicParsing).links | Select-Object -ExpandProperty href | Select-String "windows-amd64.msi$" | Select-Object -First 1)
$velociraptorMSIPath = 'C:\Users\vagrant\AppData\Local\Temp\velociraptor.msi'
$velociraptorLogFile = 'c:\Users\vagrant\AppData\Local\Temp\velociraptor_install.log'
If (-not(Test-Path $velociraptorLogFile) -or ($Update -eq $true)) {
  if ($Update -eq $true) {
    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) The update flag was set. Attempting to update..."
  }
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading Velociraptor..."
  Invoke-WebRequest -Uri "$velociraptorDownloadUrl" -OutFile $velociraptorMSIPath
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing Velociraptor..."
  Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/i $velociraptorMSIPath /quiet /qn /norestart /log $velociraptorLogFile" -wait
  Copy-Item "c:\vagrant\resources\velociraptor\Velociraptor.config.yaml" "C:\Program Files\Velociraptor"
  Restart-Service Velociraptor
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Velociraptor successfully installed!"
} Else {
  Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Velociraptor was already installed. Moving On."
}
If ((Get-Service -name Velociraptor).Status -ne "Running")
{
  Throw "Velociraptor service is not running"
}


