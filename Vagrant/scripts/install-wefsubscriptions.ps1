Write-Host "Installing WEF Subscriptions"

Write-Host "Copying Custom Event Channels DLL"
Copy-Item c:\vagrant\resources\windows-event-forwarding-master\windows-event-channels\CustomEventChannels.dll c:\windows\system32
Copy-Item c:\vagrant\resources\windows-event-forwarding-master\windows-event-channels\CustomEventChannels.man c:\windows\system32

Write-Host "Installing Custom Event Channels Manifest"
wevtutil im "c:\windows\system32\CustomEventChannels.man"
Write-Host "Resizing Channels to 4GB"
$xml = wevtutil el | select-string -pattern "WEC"
foreach ($subscription in $xml) { wevtutil sl $subscription /ms:4294967296 }

Write-Host "Starting the Windows Event Collector Service"
net start wecsvc

Write-Host "Creating custom event subscriptions"
cd c:\vagrant\resources\windows-event-forwarding-master\wef-subscriptions
cmd /c "for /r %i in (*.xml) do wecutil cs %i"

Write-Host "Enabling custom event subscriptions"
cmd /c "for /r %i in (*.xml) do wecutil ss %~ni /e:true"

Write-Host "Enabling WecUtil Quick Config"
wecutil qc /q:true
