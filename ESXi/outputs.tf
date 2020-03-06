output "dc_ips" {
  value = esxi_guest.dc.network_interfaces
}


output "wef_ips" {
  value = esxi_guest.wef.network_interfaces
}


output "win10_ips" {
  value = esxi_guest.win10.network_interfaces
}
