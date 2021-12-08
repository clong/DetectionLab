output "logger_interfaces" {
  value = esxi_guest.logger.network_interfaces
}

output "logger_ips" {
  value = esxi_guest.logger.ip_address
}

output "dc_interfaces" {
  value = esxi_guest.dc.network_interfaces
}

output "dc_ips" {
  value = esxi_guest.dc.ip_address
}

output "wef_interfaces" {
  value = esxi_guest.wef.network_interfaces
}

output "wef_ips" {
  value = esxi_guest.wef.ip_address
}

output "win10_interfaces" {
  value = esxi_guest.win10.network_interfaces
}

output "win10_ips" {
  value = esxi_guest.win10.ip_address
}

resource "local_file" "AnsibleInventory" {
 content = templatefile("./inventory.tmpl",
 {
  dc_ip = esxi_guest.dc.ip_address,
  logger_ip = esxi_guest.logger.ip_address,
  wef_ip = esxi_guest.workstation1.ip_address,
  win10_ip = esxi_guest.workstation2.ip_address,
 }
 )
 filename = "./ansible/inventory.yml"
}

