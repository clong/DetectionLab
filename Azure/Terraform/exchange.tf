## Remove the block comment to enable the creation of the Exchange server
/*
module "exchange" {
  source = "./modules/exchange"
  resource_group_name = azurerm_resource_group.detectionlab.name
  region = var.region
  subnet_id = azurerm_subnet.detectionlab-subnet.id
}
*/

