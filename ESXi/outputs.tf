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

output "exchange_interfaces" {
  value = esxi_guest.exchange[0].network_interfaces
}

output "exchange_ips" {
  value = "${var.create_exchange_server ? esxi_guest.exchange[0].ip_address : null}"
}

output "win10_interfaces" {
  value = esxi_guest.win10.network_interfaces
}

output "win10_ips" {
  value = esxi_guest.win10.ip_address
}
