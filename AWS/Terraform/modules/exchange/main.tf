# Shouldnt need this but alas: https://github.com/hashicorp/terraform-provider-aws/issues/14917
provider "aws" {
  region = var.region
}

resource "aws_instance" "exchange" {
  instance_type = "t3.xlarge"

  provisioner "remote-exec" {
    inline = [
      "choco install -force -y winpcap",
      "ipconfig /renew",
      "powershell.exe -c \"Add-Content 'c:\\windows\\system32\\drivers\\etc\\hosts' '        192.168.38.103    wef.windomain.local'\"",
      "powershell.exe -c \"Add-Content 'c:\\windows\\system32\\drivers\\etc\\hosts' '        192.168.38.102    dc.windomain.local'\"",
      "powershell.exe -c \"Add-Content 'c:\\windows\\system32\\drivers\\etc\\hosts' '        192.168.38.102    windomain.local'\"",
      ]

    connection {
      type     = "winrm"
      user     = "vagrant"
      password = "vagrant"
      host     = coalesce(self.public_ip, self.private_ip)
    }
  }

  # Uses the local variable if external data source resolution fails
  ami = coalesce(var.exchange_ami, data.aws_ami.exchange_ami.image_id)

  tags = merge(var.custom-tags, tomap(
    {"Name" = "${var.instance_name_prefix}exchange.windomain.local"}
  ))

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_id
  private_ip             = "192.168.38.106"

  root_block_device {
    delete_on_termination = true
  }
}

