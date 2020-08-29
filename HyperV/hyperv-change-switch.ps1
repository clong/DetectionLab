# See: https://www.thomasmaurer.ch/2016/01/change-hyper-v-vm-switch-of-virtual-machines-using-powershell/
# https://superuser.com/questions/1354658/hyperv-static-ip-with-vagrant#:~:text=%20HyperV%20-%20Static%20Ip%20with%20Vagrant%20,static%20IP%20address%20will%20be%20set...%20More%20

param ([String] $vmname)
Get-VM "$vmname" | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName "NATSwitch"
