# Shouldnt need this but alas: https://github.com/hashicorp/terraform-provider-aws/issues/14917
provider "aws" {
  region                  = var.region
  profile                 = var.profile
  shared_credentials_file = var.shared_credentials_file
}

resource "aws_instance" "exchange" {
  instance_type = "t3.xlarge"

    provisioner "file" {
    source      = "scripts/bootstrap.ps1"
    destination = "C:\\Temp\\bootstrap.ps1"

    connection {
      type     = "winrm"
      user     = "vagrant"
      password = "vagrant"
      host     = coalesce(self.public_ip, self.private_ip)
    }
  }

  provisioner "remote-exec" {
    inline = ["powershell.exe -File C:\\Temp\\bootstrap.ps1"]

    connection {
      type     = "winrm"
      user     = "vagrant"
      password = "vagrant"
      host     = coalesce(self.public_ip, self.private_ip)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "powershell.exe -c \"Get-Service | ?{$_.Name -ilike 'MSexch*'} | Set-Service -StartupType Automatic\"",
      "powershell.exe -c {$optionalServices = 'MSExchangeAntispamUpdate','MSExchangeEdgeSync','MSExchangeIMAP4','MSExchangeIMAP4BE','MSExchangePOP3','MSExchangePOP3BE','WSBExchange','MSExchangeTransportLogSearch','MSExchangeUM','MSExchangeUMCR'; ForEach ($service in $optionalServices) { Set-Service -Name $service -StartupType Disabled }}",
      "shutdown /r /f /t 1",
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
    { "Name" = "${var.instance_name_prefix}exchange.windomain.local" }
  ))

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_id
  private_ip             = "192.168.56.106"

  root_block_device {
    delete_on_termination = true
  }
}