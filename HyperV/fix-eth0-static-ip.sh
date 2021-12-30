fix_eth0_static_ip() {
  # There's a fun issue where dhclient keeps messing with eth0 despite the fact
  # that eth0 has a static IP set. We workaround this by setting a static DHCP lease.
  echo -e 'interface "eth0" {
    send host-name = gethostname();
    send dhcp-requested-address 192.168.56.105;
  }' >>/etc/dhcp/dhclient.conf
  netplan apply
  # Set the ip address on eth0 and rename the adapter to eth1
  ETH0_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  if [ "$ETH0_IP" != "192.168.56.105" ]; then
    MAC=$(ip a | grep "link/ether" | cut -d ' ' -f 6)
     cat > /etc/netplan/01-netcfg.yaml << EOL
network:
  ethernets:
    eth0:
      match:
        macaddress: $MAC
      dhcp4: no
      addresses: [192.168.56.105/24]
      gateway4: 192.168.56.1
      nameservers:
        addresses: [8.8.8.8,8.8.4.4]
      set-name: eth1
  version: 2
  renderer: networkd
EOL
  fi
}

fix_eth0_static_ip