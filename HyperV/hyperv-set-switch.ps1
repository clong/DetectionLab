# See: https://www.thomasmaurer.ch/2016/01/change-hyper-v-vm-switch-of-virtual-machines-using-powershell/
param ([String] $vmname)
# Get-VM $vmname | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "NATSwitch"
if (((Get-VMNetworkAdapter -VMName $vmname).Name).Contains("NATAdapter")){
  Write-Host "The NATAdapter already exits"
} else {
  Add-VMNetworkAdapter -VMName $vmname -SwitchName "NATSwitch" -Name NATAdapter -DeviceNaming On
}
