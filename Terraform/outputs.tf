output region {
  value = "${var.region}"
}

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

output "latest_dc_ami_id" {
  value = "${data.aws_ami.dc_ami.image_id}"
}

output "latest_wef_ami_id" {
  value = "${data.aws_ami.wef_ami.image_id}"
}

output "latest_win10_ami_id" {
  value = "${data.aws_ami.wef_ami.image_id}"
}
