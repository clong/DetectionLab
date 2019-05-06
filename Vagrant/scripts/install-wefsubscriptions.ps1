# Purpose: Imports the custom Windows Event Channel and XML subscriptions on the WEF host
# Note: This only needs to be installed on the WEF server

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing WEF Subscriptions..."

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Copying Custom Event Channels DLL..."
if (-not (Test-Path "$env:windir\system32\CustomEventChannels.dll"))
{
    Copy-Item c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\windows-event-channels\CustomEventChannels.dll "$env:windir\system32"
    Copy-Item c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\windows-event-channels\CustomEventChannels.man "$env:windir\system32"

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Installing Custom Event Channels Manifest..."
    wevtutil im "c:\windows\system32\CustomEventChannels.man"
    Write-Host "Resizing Channels to 4GB..."
    $xml = wevtutil el | select-string -pattern "WEC"
    foreach ($subscription in $xml) { wevtutil sl $subscription /ms:4294967296 }

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Starting the Windows Event Collector Service..."
    net start wecsvc

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Creating custom event subscriptions..."
    cd c:\Users\vagrant\AppData\Local\Temp\windows-event-forwarding-master\wef-subscriptions
    cmd /c "for /r %i in (*.xml) do wecutil cs %i"

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Enabling custom event subscriptions..."
    cmd /c "for /r %i in (*.xml) do wecutil ss %~ni /e:true"

    Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Enabling WecUtil Quick Config..."
    wecutil qc /q:true
}
else
{
  Write-Host "WEF Subscriptions are already installed, moving on..."
  if ((Get-Service -Name wecsvc).Status -ne "Running")
  {
    net start wecsvc
  }
}
Start-Sleep -Seconds 60
if ((Get-Service -Name wecsvc).Status -ne "Running")
{
    throw "Windows Event Collector failed to start"
}
