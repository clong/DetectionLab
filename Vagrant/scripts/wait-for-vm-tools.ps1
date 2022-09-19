# Purpose: Prevents the host from rebooting until VMware Tools or VBox Guest Additions is detected running

$tries=1; 
While ($tries -lt 10) { 
    $vmware_service = Get-Service -Name VMTools -ErrorAction SilentlyContinue
    $vbox_service = Get-Service -Name VBoxService -ErrorAction SilentlyContinue
    If(($vmware_service.length -eq 0) -and ($vbox_service.length -eq 0)) {
        Write-Host "Waiting for VM guest tools to be installed"
        Start-Sleep 10
    } Else {
        If ($vbox_service.length -gt 0) {
          Write-Host "Found Virtualbox Guest Additions!"
          $service = "VBoxService"
        }
        If ($vmware_service.length -gt 0) {
          Write-Host "Found VMware Tools!"
          $service = "VMTools"
        }
        If((get-service -name $service).Status -ne "Running") {
            Write-Host "Waiting for the $service service to start" 
            Start-Sleep 5
        } Else {
            Write-Host "$service started successfully!"
        }
    }
    $tries+=1
}


