# Installs the AWS Enhanced Networking for Windows
  Write-Host "Installing the AWS Enhanced Networking Driver"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $url="https://s3.amazonaws.com/ec2-windows-drivers-downloads/ENA/Latest/AwsEnaNetworkDriver.zip"
  (New-Object System.Net.WebClient).DownloadFile($url, "$env:TEMP\AwsEnaNetworkDriver.zip")
  Expand-Archive -Path $env:TEMP\AwsEnaNetworkDriver.zip -DestinationPath $env:TEMP\AwsEnaNetworkDriver -Force
  . $env:TEMP\AwsEnaNetworkDriver\install.ps1

  rm $env:TEMP\AwsEnaNetworkDriver.zip
  rm -recurse $env:TEMP\AwsEnaNetworkDriver
