# for debugging
# wait until a file has been removed from desktop
$file = "C:\users\vagrant\Desktop\delete-to-continue.txt"

if (-Not (Test-Path $file)) {
  Write-Host "Remove me" | Out-File $file
}

Write-Host "Wait until someone removes $file"

while (Test-Path $file) {
  Sleep 1
}

Write-Host "Done waiting!"
