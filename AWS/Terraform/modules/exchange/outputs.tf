output "exchange_public_ip" {
  value = aws_instance.exchange.public_ip
}

output "exchange_url" {
  value = local.exchange_url
}