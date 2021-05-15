## Remove the block comment to enable the creation of the Exchange server
/*
module "exchange" {
  source = "./modules/exchange"
  region = var.region
  subnet_id = aws_subnet.default.id
  security_group_id = [aws_security_group.windows.id]
  instance_name_prefix = var.instance_name_prefix
  custom-tags = var.custom-tags
  exchange_ami = var.exchange_ami
}
*/

