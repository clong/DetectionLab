Write-Host Creating group docker
net localgroup docker /add
$username = $env:USERNAME
Write-Host Adding user $username to group docker
net localgroup docker $username /add
