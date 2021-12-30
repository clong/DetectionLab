# Specify the provider and access details
provider "aws" {
  shared_credentials_file = var.shared_credentials_file
  region                  = var.region
  profile                 = var.profile
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "192.168.0.0/16"
  tags = var.custom-tags
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags = var.custom-tags
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.default.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "192.168.56.0/24"
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags = var.custom-tags
}

# Adjust VPC DNS settings to not conflict with lab
resource "aws_vpc_dhcp_options" "default" {
  domain_name          = "windomain.local"
  domain_name_servers  = concat(["192.168.56.102"], var.external_dns_servers)
  netbios_name_servers = ["192.168.56.102"]
  tags = var.custom-tags
}

resource "aws_vpc_dhcp_options_association" "default" {
  vpc_id          = aws_vpc.default.id
  dhcp_options_id = aws_vpc_dhcp_options.default.id
}

# Our default security group for the logger host
resource "aws_security_group" "logger" {
  name        = "logger_security_group"
  description = "DetectionLab: Security Group for the logger host"
  vpc_id      = aws_vpc.default.id
  tags = var.custom-tags

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  # Splunk access
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  # Fleet access
  ingress {
    from_port   = 8412
    to_port     = 8412
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  # Guacamole access
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  # Velociraptor access
    ingress {
    from_port   = 9999
    to_port     = 9999
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  # Allow all traffic from the private subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.56.0/24"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "windows" {
  name        = "windows_security_group"
  description = "DetectionLab: Security group for the Windows hosts"
  vpc_id      = aws_vpc.default.id
  tags = var.custom-tags

  # RDP
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  # WinRM
  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  # Windows ATA
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  # Allow all traffic from the private subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.56.0/24"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = var.public_key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "logger" {
  instance_type = "t3.medium"
  ami           = coalesce(var.logger_ami, data.aws_ami.logger_ami.image_id)

  tags = merge(var.custom-tags, tomap(
    {"Name" = "${var.instance_name_prefix}logger"}
  ))

  subnet_id              = aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.logger.id]
  key_name               = aws_key_pair.auth.key_name
  private_ip             = "192.168.56.105"

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -qq update",
      "sudo git clone https://github.com/clong/DetectionLab.git /opt/DetectionLab",
      "sudo chmod +x /opt/DetectionLab/Vagrant/logger_bootstrap.sh",
      "sudo sed -i 's#/vagrant/resources#/opt/DetectionLab/Vagrant/resources#g' /opt/DetectionLab/Vagrant/logger_bootstrap.sh",
      "sudo yq d -i /etc/suricata/suricata.yaml af-packet[1]", 
      "sudo sed -i '1s/^/\\%YAML 1.1\\n---\\n/g' /etc/suricata/suricata.yaml",
      "sudo cp /opt/DetectionLab/Vagrant/resources/fleet/fleet.service /etc/systemd/system/fleet.service && sudo systemctl daemon-reload && sudo service fleet restart",
      "sudo service suricata restart",
      "sudo /opt/DetectionLab/Vagrant/logger_bootstrap.sh splunk_only",
      "sudo systemctl stop guacd",
      "sudo useradd -M -d /var/lib/guacd/ -r -s /sbin/nologin -c 'Guacd User' guacd",
      "sudo mkdir /var/lib/guacd && sudo chown -R guacd: /var/lib/guacd && sudo sed -i 's/daemon/guacd/' /lib/systemd/system/guacd.service",
      "sudo systemctl daemon-reload && sudo systemctl start guacd"
    ]

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "vagrant"
      password    = "vagrant"
    }
  }

  root_block_device {
    delete_on_termination = true
    volume_size           = 64 
  }
}

resource "aws_instance" "dc" {
  instance_type = "t3.medium"
  depends_on = [
    aws_vpc_dhcp_options.default,
    aws_vpc_dhcp_options_association.default
  ]

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

  # Uses the local variable if external data source resolution fails
  ami = coalesce(var.dc_ami, data.aws_ami.dc_ami.image_id)

  tags = merge(var.custom-tags, tomap(
    {"Name" = "${var.instance_name_prefix}dc.windomain.local"}
  ))

  subnet_id              = aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.windows.id]
  private_ip             = "192.168.56.102"

  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_instance" "wef" {
  instance_type = "t3.medium"
    depends_on = [
    aws_vpc_dhcp_options.default,
    aws_vpc_dhcp_options_association.default
  ]

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

  # Uses the local variable if external data source resolution fails
  ami = coalesce(var.wef_ami, data.aws_ami.wef_ami.image_id)

  tags = merge(var.custom-tags, tomap(
    {"Name" = "${var.instance_name_prefix}wef.windomain.local"}
  ))

  subnet_id              = aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.windows.id]
  private_ip             = "192.168.56.103"

  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_instance" "win10" {
  instance_type = "t2.large"
    depends_on = [
    aws_vpc_dhcp_options.default,
    aws_vpc_dhcp_options_association.default
  ]

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

  # Uses the local variable if external data source resolution fails
  ami = coalesce(var.win10_ami, data.aws_ami.win10_ami.image_id)

  tags = merge(var.custom-tags, tomap(
    {"Name" = "${var.instance_name_prefix}win10.windomain.local"}
  ))

  subnet_id              = aws_subnet.default.id
  vpc_security_group_ids = [aws_security_group.windows.id]
  private_ip             = "192.168.56.104"

  root_block_device {
    delete_on_termination = true
  }
}
