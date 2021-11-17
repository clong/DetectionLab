output "exchange_interfaces" {
  value = proxmox_vm_qemu.exchange.network
}

output "exchange_ips" {
  value = proxmox_vm_qemu.exchange.default_ipv4_address
}