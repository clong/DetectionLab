# Purpose: Imports the custom Windows Event Channel and XML subscriptions on the WEF host
# Note: This only needs to be installed on the WEF server

Write-Host "Installing WEF Subscriptions"

Write-Host "Copying Custom Event Channels DLL"
if (-not (Test-Path "$env:windir\system32\CustomEventChannels.dll"))
{
    Copy-Item c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\windows-event-channels\CustomEventChannels.dll "$env:windir\system32"
    Copy-Item c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\windows-event-channels\CustomEventChannels.man "$env:windir\system32"

    Write-Host "Installing Custom Event Channels Manifest"
    wevtutil im "c:\windows\system32\CustomEventChannels.man"
    Write-Host "Resizing Channels to 4GB"
    $xml = wevtutil el | select-string -pattern "WEC"
    foreach ($subscription in $xml) { wevtutil sl $subscription /ms:4294967296 }

    Write-Host "Starting the Windows Event Collector Service"
    net start wecsvc

    Write-Host "Creating custom event subscriptions"
    cd c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\wef-subscriptions
    cmd /c "for /r %i in (*.xml) do wecutil cs %i"

    Write-Host "Enabling custom event subscriptions"
    cmd /c "for /r %i in (*.xml) do wecutil ss %~ni /e:true"

    Write-Host "Enabling WecUtil Quick Config"
    wecutil qc /q:true
}
else 
{
    Write-Host "WEF Subscriptions already installed, moving on"
    net start wecsvc
}
Start-Sleep -Seconds 60
if ((Get-Service -Name wecsvc).Status -ne "Running")
{
    throw "Windows Event Collector service was not running"
}