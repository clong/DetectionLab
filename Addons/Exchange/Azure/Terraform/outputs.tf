output "exchange_public_ip" {
  value = azurerm_public_ip.exchange-publicip
}

output "exchange_url" {
  value = local.exchange_url
}
