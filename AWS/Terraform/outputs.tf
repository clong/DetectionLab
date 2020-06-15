output "region" {
  value = var.region
}

output "logger_public_ip" {
  value = aws_instance.logger.public_ip
}

output "dc_public_ip" {
  value = aws_instance.dc.public_ip
}

output "wef_public_ip" {
  value = aws_instance.wef.public_ip
}

output "win10_public_ip" {
  value = aws_instance.win10.public_ip
}

output "ata_url" {
  value = local.ata_url
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
