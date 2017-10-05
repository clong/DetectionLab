# Downloads and unzips a copy of the Palantir WEF Github Repo
Write-Host "Downloading and unzipping the Palantir Windows Event Forwarding Repo from Github..."

$wefRepoPath = 'c:\vagrant\resources\master.zip'

Invoke-WebRequest -Uri "https://github.com/palantir/windows-event-forwarding/archive/master.zip" -OutFile $wefRepoPath
Expand-Archive -path "$wefRepoPath" -destinationpath 'c:\vagrant\resources\' -Force
