Write-Host "Installing WEF Subscriptions"
Expand-Archive c:\vagrant\resources\wef-subscriptions-master.zip -DestinationPath c:\Tools
Expand-Archive c:\vagrant\resources\windows-event-channels-master.zip -DestinationPath c:\Tools

Write-Host "Copying Custom Event Channels DLL"
Copy-Item c:\Tools\windows-event-channels-master\CustomEventChannels.dll c:\windows\system32
Copy-Item c:\Tools\windows-event-channels-master\CustomEventChannels.man c:\windows\system32

Write-Host "Installing Custom Event Channels Manifest"
wevtutil im "c:\windows\system32\CustomEventChannels.man"
Write-Host "Resizing Channels to 4GB"
$xml = wevtutil el | select-string -pattern "WEC"
foreach ($subscription in $xml) { wevtutil sl $subscription /ms:4294967296 }

Write-Host "Starting the Windows Event Collector Service"
net start wecsvc

Write-Host "Creating custom event subscriptions"
cd c:\Tools\wef-subscriptions-master
cmd /c "for /r %i in (*.xml) do wecutil cs %i"

Write-Host "Enabling custom event subscriptions"
cmd /c "for /r %i in (*.xml) do wecutil ss %~ni /e:true"

Write-Host "Enabling WecUtil Quick Config"
wecutil qc /q:true
