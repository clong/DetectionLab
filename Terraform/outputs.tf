output "logger_public_ip" {
  value = "${aws_instance.logger.public_ip}"
}

output "dc_public_ip" {
  value = "${aws_instance.dc.public_ip}"
}

output "wef_public_ip" {
  value = "${aws_instance.wef.public_ip}"
}

output "win10_public_ip" {
  value = "${aws_instance.win10.public_ip}"
}
