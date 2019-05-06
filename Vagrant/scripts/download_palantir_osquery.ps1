# Purpose: Downloads and unzips a copy of the Palantir osquery Github Repo. These configs are added to the Fleet server in bootstrap.sh.
# The items from this config file are used later in install-osquery.ps1
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading and unzipping the Palantir osquery Repo from Github..."

$osqueryRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\osquery-Master.zip'
if (-not (Test-Path $osqueryRepoPath))
{
    # GitHub requires TLS 1.2 as of 2/1/2018
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/palantir/osquery-configuration/archive/master.zip" -OutFile $osqueryRepoPath
    Expand-Archive -path "$osqueryRepoPath" -destinationpath 'c:\Users\vagrant\AppData\Local\Temp' -Force
}
else
{
    Write-Host "$osqueryRepoPath already exists. Moving On."
}
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Palantir osquery config download complete!"
