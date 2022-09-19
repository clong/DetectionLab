# Purpose: Prevents the host from rebooting until VMware Tools or VBox Guest Additions is detected running

Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Running wait-for-vm-tools.ps1..."

$tries=1; 
While ($tries -lt 10) { 
    $vmware_service = Get-Service -Name VMTools -ErrorAction SilentlyContinue
    $vbox_service = Get-Service -Name VBoxService -ErrorAction SilentlyContinue
    If(($vmware_service.length -eq 0) -and ($vbox_service.length -eq 0)) {
        Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) No tools found yet. Waiting for VM guest tools to be installed..."
        Start-Sleep 10
    } Else {
        If ($vbox_service.length -gt 0) {
          Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Found Virtualbox Guest Additions!"
          $service = "VBoxService"
        }
        If ($vmware_service.length -gt 0) {
          Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Found VMware Tools!"
          $service = "VMTools"
        }
        If((get-service -name $service).Status -ne "Running") {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) Waiting for the $service service to start" 
            Start-Sleep 5
        } Else {
            Write-Host "$('[{0:HH:mm}]' -f (Get-Date)) $service started successfully!"
            break
        }
    }
    $tries+=1
}


