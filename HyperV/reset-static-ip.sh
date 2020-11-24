reset_static_ip() {
  # The bootstrap script assumes that there are two adapters and attempts to set the ip address
  # to the eth1 adapter. This corrects the 01-netcfg.yaml file

  MAC=$(ip a | grep "link/ether" | cut -d ' ' -f 6)
  cat > /etc/netplan/01-netcfg.yaml << EOL
network:
  ethernets:
    eth0:
      match:
        macaddress: $MAC
      dhcp4: no
      addresses: [192.168.38.105/24]
      gateway4: 192.168.38.1
      nameservers:
        addresses: [8.8.8.8,8.8.4.4]
      set-name: eth1
  version: 2
  renderer: networkd
EOL
}

reset_static_ip