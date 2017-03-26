# Do not restart Docker as it creates the key.json with an unique ID
# This should not exist in the Vagrant basebox so you can spin up
# multiple Vagrant boxes for a Docker swarm etc.

Write-Host "Stopping Docker"
Stop-Service docker

Write-Host "Removing key.json to recreate key.json on first vagrant up"
rm C:\ProgramData\docker\config\key.json
