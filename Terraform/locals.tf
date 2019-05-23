locals {
  fleet_url  = "https://${aws_instance.logger.public_ip}:8412"
  splunk_url = "https://${aws_instance.logger.public_ip}:8000"
}
