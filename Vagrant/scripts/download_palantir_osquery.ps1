# Purpose: Downloads and unzips a copy of the Palantir osquery Github Repo. These configs are added to the Fleet server in bootstrap.sh.
Write-Host "Downloading and unzipping the Palantir osquery Repo from Github..."

$osqueryRepoPath = 'C:\Users\vagrant\AppData\Local\Temp\osquery-Master.zip'

Invoke-WebRequest -Uri "https://github.com/palantir/osquery-configuration/archive/master.zip" -OutFile $osqueryRepoPath
Expand-Archive -path "$osqueryRepoPath" -destinationpath 'c:\Users\vagrant\AppData\Local\Temp' -Force
