# See: https://www.petri.com/using-nat-virtual-switch-hyper-v

$NATHostIP = "192.168.38.1"
$NATNetPrefixLength = 24
$NATNet = "192.168.38.0/$NATNetPrefixLength"
$NATNetName = "NATNetwork"
$NATSwitchName = "NATSwitch"
$NATSwitchNameAlias = "vEthernet ($NATSwitchName)"

# Check our NAT switch exists, create it and configure it if it doesn't.
If ("$NATSwitchName" -in (Get-VMSwitch | Select-Object -ExpandProperty Name) -eq $FALSE) {
    "Creating Internal-only switch named ""$NatSwitchName"" on Windows Hyper-V host..."

    New-VMSwitch -SwitchName $NATSwitchName -SwitchType Internal
    New-NetIPAddress -IPAddress $NATHostIP -PrefixLength $NATNetPrefixLength -InterfaceAlias $NATSwitchNameAlias
    New-NetNAT -Name $NATNetName -InternalIPInterfaceAddressPrefix $NATNet

} else {
    """$NATSwitchName"" VM Switch on Hyper-V host for guest static IP configuration already exists; skipping..."
}

# Check that our Hyper-V host has the proper gateway address for the NAT Network.
If (@(Get-NetIPAddress | Where-Object {$_.IPAddress -eq "$NATHostIP" -and $_.InterfaceAlias -eq "$NATSwitchNameAlias"}).Count -eq 1) {
    "Registering new IP address $NATHostIP on Windows Hyper-V host..."

    New-NetIPAddress -IPAddress $NATHostIP -PrefixLength $NATNetPrefixLength -InterfaceAlias $NATSwitchNameAlias

} else {
    """$NATHostIP"" Hyper-V host gateway address for guest static IP configuration already registered; skipping..."
}

# Check that our Hyper-V host has the proper NAT Network setup
If ("$NATNet" -in (Get-NetNAT | Select-Object -ExpandProperty InternalIPInterfaceAddressPrefix) -eq $FALSE) {
    "Registering new NAT adapter for $NATNet on Windows Hyper-V host..."

    New-NetNAT -Name $NATNetName -InternalIPInterfaceAddressPrefix $NATNet

} else {
    """$NATNet"" Hyper-V host NAT Network for guest static IP configuration already registered; skipping"
}