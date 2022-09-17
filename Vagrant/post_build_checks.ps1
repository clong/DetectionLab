function download {
    param(
      [string]$URL,
      [string]$PatternToMatch,
      [switch]$SuccessOn401
    )
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $wc = New-Object System.Net.WebClient
    try {
      $result = $wc.DownloadString($URL)
      
      if ($result -like "*$PatternToMatch*") {
        return $true
      } else {
        return $false
      }
    }
    catch {
      if ($_.Exception.InnerException.Response.StatusCode -eq 401 -and $SuccessOn401.IsPresent) {
        return $true
      } else {
        Write-Host "Error occured on webrequest: $_" -ForegroundColor red
        return $false
      }
    }
}

function post_build_checks {
    $checkmark = ([char]8730)

    if ((Get-NetAdapter | where {$_.name -eq "VMware Network Adapter VMnet2"}).ifIndex) {
      Write-Host '[*] Verifying vmnet2 interface has its IP address set correctly'
      $vmnet2idx=(Get-NetAdapter | where {$_.name -eq "VMware Network Adapter VMnet2"}).ifIndex
      if ((get-netipaddress -AddressFamily IPv4 | where { $_.InterfaceIndex -eq $vmnet2idx }).IPAddress -ne "192.168.56.1") {
        Write-Host '[!] Your vmnet2 network adapter is not set with a static IP address of 192.168.56.1' -ForegroundColor red
        Write-Host '[!] Please match your adapter settings to the screenshot shown here: https://github.com/clong/DetectionLab/issues/681#issuecomment-890442441' -ForegroundColor red
      }
      Else {
        Write-Host '  ['$($checkmark)'] VMNet2 is correctly set to 192.168.56.1!' -ForegroundColor Green
      }
    }

    Write-Host '[*] Verifying that Splunk is reachable...'
    $SPLUNK_CHECK = download -URL 'https://192.168.56.105:8000/en-US/account/login?return_to=%2Fen-US%2F' -PatternToMatch 'This browser is not supported by Splunk'
    if ($SPLUNK_CHECK -eq $false) {
        Write-Host '[!] Splunk was unreachable and may not have installed correctly.' -ForegroundColor red
    }
    else {
        Write-Host '  ['$($checkmark)'] Splunk is running and reachable!' -ForegroundColor Green
    }
    Write-Host ''

    Write-Host '[*] Verifying that Fleet is reachable...'
    $FLEET_CHECK = download -URL 'https://192.168.56.105:8412' -PatternToMatch 'Fleet for osquery'
    if ($FLEET_CHECK -eq $false) {
        Write-Host '[!] Fleet was unreachable and may not have installed correctly.' -ForegroundColor red
    }
    else {
        Write-Host '  ['$($checkmark)'] Fleet is running and reachable!' -ForegroundColor Green
    }
    Write-Host ''

    Write-Host '[*] Verifying that Velociraptor is reachable...'
    $VELOCIRAPTOR_CHECK = download -URL 'https://192.168.56.105:9999' -SuccessOn401
    if ($VELOCIRAPTOR_CHECK -eq $false) {
        Write-Host '[!] Velociraptor was unreachable and may not have installed correctly.' -ForegroundColor red
    }
    else {
        Write-Host '  ['$($checkmark)'] Velociraptor is running and reachable!' -ForegroundColor Green
    }
    Write-Host ''

    Write-Host '[*] Verifying that Guacamole is reachable...'
    $GUACAMOLE_CHECK = download -URL 'http://192.168.56.105:8080/guacamole' -PatternToMatch 'Apache Software'
    if ($GUACAMOLE_CHECK -eq $false) {
        Write-Host '[!] Guacamole was unreachable and may not have installed correctly.' -ForegroundColor red
    }
    else {
        Write-Host '  ['$($checkmark)'] Guacamole is running and reachable!' -ForegroundColor Green
    }
    Write-Host ''
}

post_build_checks
