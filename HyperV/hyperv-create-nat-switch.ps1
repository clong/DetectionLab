# See: https://www.petri.com/using-nat-virtual-switch-hyper-v

If ("NATSwitch" -in (Get-VMSwitch | Select-Object -ExpandProperty Name) -eq $FALSE) {
    'Creating Internal-only switch named "NATSwitch" on Windows Hyper-V host...'

    New-VMSwitch -SwitchName "NATSwitch" -SwitchType Internal

    New-NetIPAddress -IPAddress 192.168.38.1 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"

    New-NetNAT -Name "NATNetwork" -InternalIPInterfaceAddressPrefix 192.168.38.0/24
}
else {
    '"NATSwitch" for static IP configuration already exists; skipping'
}

If ("192.168.38.1" -in (Get-NetIPAddress | Select-Object -ExpandProperty IPAddress) -eq $FALSE) {
    'Registering new IP address 192.168.38.1 on Windows Hyper-V host...'

    New-NetIPAddress -IPAddress 192.168.38.1 -PrefixLength 24 -InterfaceAlias "vEthernet (NATSwitch)"
}
else {
    '"192.168.38.1" for static IP configuration already registered; skipping'
}

If ("192.168.38.0/24" -in (Get-NetNAT | Select-Object -ExpandProperty InternalIPInterfaceAddressPrefix) -eq $FALSE) {
    'Registering new NAT adapter for 192.168.38.0/24 on Windows Hyper-V host...'

    New-NetNAT -Name "NATNetwork" -InternalIPInterfaceAddressPrefix 192.168.38.0/24
}
else {
    '"192.168.38.0/24" for static IP configuration already registered; skipping'
}