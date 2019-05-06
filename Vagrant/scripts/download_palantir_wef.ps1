# Purpose: Downloads and unzips a copy of the Palantir WEF Github Repo. This includes WEF subscriptions and custom WEF channels.

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Downloading and unzipping the Palantir Windows Event Forwarding Repo from Github..."

$wefRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\wef-Master.zip'

If (-not (Test-Path $wefRepoPath))
{
    # GitHub requires TLS 1.2 as of 2/1/2018
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/palantir/windows-event-forwarding/archive/master.zip" -OutFile $wefRepoPath
    Expand-Archive -path "$wefRepoPath" -destinationpath 'c:\Users\vagrant\AppData\Local\Temp' -Force
}
else
{
    Write-Host "$wefRepoPath already exists. Moving On."
}
Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Palantir WEF download complete!"
