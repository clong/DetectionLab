output "logger_interfaces" {
  value = proxmox_vm_qemu.logger.network
}

output "logger_ips" {
  value = proxmox_vm_qemu.logger.default_ipv4_address
}

output "dc_interfaces" {
  value = proxmox_vm_qemu.dc.network
}

output "dc_ips" {
  value = proxmox_vm_qemu.dc.default_ipv4_address
}

output "wef_interfaces" {
  value = proxmox_vm_qemu.wef.network
}

output "wef_ips" {
  value = proxmox_vm_qemu.wef.default_ipv4_address
}

output "win10_interfaces" {
  value = proxmox_vm_qemu.win10.network
}

output "win10_ips" {
  value = proxmox_vm_qemu.win10.default_ipv4_address
}