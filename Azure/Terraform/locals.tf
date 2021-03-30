locals {
  fleet_url  = "https://${azurerm_public_ip.logger-publicip.ip_address}:8412"
  splunk_url = "https://${azurerm_public_ip.logger-publicip.ip_address}:8000"
  ata_url    = "https://${azurerm_public_ip.wef-publicip.ip_address}"
  guacamole_url = "http://${azurerm_public_ip.logger-publicip.ip_address}:8080/guacamole"
  velociraptor_url = "https://${azurerm_public_ip.logger-publicip.ip_address}:9999"
  exchange_url    = "https://${var.create_exchange_server ? azurerm_public_ip.exchange-publicip[0].ip_address : ""}"
}
