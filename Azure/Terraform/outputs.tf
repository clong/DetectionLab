output "region" {
  value = var.region
}

output "logger_public_ip" {
  value = azurerm_public_ip.logger-publicip.ip_address
}

output "dc_public_ip" {
  value = azurerm_public_ip.dc-publicip.ip_address
}

output "wef_public_ip" {
  value = azurerm_public_ip.wef-publicip.ip_address
}

output "win10_public_ip" {
  value = azurerm_public_ip.win10-publicip.ip_address 
}

output "fleet_url" {
  value = local.fleet_url
}

output "splunk_url" {
  value = local.splunk_url
}

output "guacamole_url" {
  value = local.guacamole_url
}

output "velociraptor_url" {
  value = local.velociraptor_url
}
/*
output "exchange_public_ip" {
  value = module.exchange.exchange_public_ip
}

output "exchange_url" {
  value = module.exchange.exchange_public_ip
}
  */
