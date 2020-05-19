# Purpose: Re-arms the expiration timer on expiring Windows eval images and fixes activation issues

# Check to see if there are days left on the timer or if it's just expired
$regex = cscript c:\windows\system32\slmgr.vbs /dlv | select-string -Pattern "\((\d+) day\(s\)|grace time expired"
if ($regex.Matches.Value -eq "grace time expired") {
  # If it shows expired, it's likely it wasn't properly activated
  Write-Host "It appears Windows was not properly activated. Attempting to resolve..."
  try {
    # The TrustedInstaller service MUST be running for activation to succeed
    Set-Service TrustedInstaller -StartupType Automatic
    Start-Service TrustedInstaller
    Start-Sleep 10
    # Attempt to activate
    cscript c:\windows\system32\slmgr.vbs /ato
  } catch {
    Write-Host "Something went wrong trying to reactivate Windows..."
  }
  # If activation was successful, the regex should match 90 or 180 (Win10 or Win2016)
  $regex = cscript c:\windows\system32\slmgr.vbs /dlv | select-string -Pattern "\((\d+) day\(s\)"
}  
$days_left = $regex.Matches.Groups[1].Value

if ($days_left -as [int] -lt 30) {
  write-host "Less than 30 days remaining before Windows expiration. Attempting to rearm..."
  try {
    cscript c:\windows\system32\slmgr.vbs /rearm
  } catch {
    Write-Host "Something went wrong trying to re-arm the image..."
  }
} else {
  Write-Host "$days_left days left until expiration, no need to rearm."
}
