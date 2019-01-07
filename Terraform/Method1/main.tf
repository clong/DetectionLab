# Terraform configuration to be used with DetectionLab Method1
# Before using this, you must fill out the variables in terraform.tfvars
# Please follow the instructions in https://github.com/clong/DetectionLab/blob/master/Terraform/Method1/Method1.md

variable "region" {
  default = "us-west-1"
}
variable "shared_credentials_file" {
  type = "string"
}
variable "key_name" {
  default = "id_terraform"
}
variable "public_key_path" {
  type = string
}
variable "ip_whitelist" {
  type = "list"
}
variable "logger_ami" {}
variable "dc_ami" {}
variable "wef_ami" {}
variable "win10_ami" {}

# Specify the provider and access details
provider "aws" {
  shared_credentials_file = "${var.shared_credentials_file}"
  region = "${var.region}"
  profile = "terraform"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "192.168.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "192.168.38.0/24"
  map_public_ip_on_launch = true
}

# Our default security group for the logger host
resource "aws_security_group" "logger" {
  name        = "logger_security_group"
  description = "DetectionLab: Security Group for the logger host"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = "${var.ip_whitelist}"
  }

  # Splunk access
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = "${var.ip_whitelist}"
  }

  # Fleet access
  ingress {
    from_port   = 8412
    to_port     = 8412
    protocol    = "tcp"
    cidr_blocks = "${var.ip_whitelist}"
  }

  # Caldera access
  ingress {
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = "${var.ip_whitelist}"
  }

  # Allow all traffic from the private subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.38.0/24"]
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
  vpc_id      = "${aws_vpc.default.id}"

  # RDP
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = "${var.ip_whitelist}"
  }

  # WinRM
  ingress {
    from_port   = 5985
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = "${var.ip_whitelist}"
  }

  # Allow all traffic from the private subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.38.0/24"]
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
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "logger" {
  instance_type = "t3.medium"
  ami = "${var.logger_ami}"
  tags {
    Name = "logger"
  }
  subnet_id = "${aws_subnet.default.id}"
  vpc_security_group_ids = ["${aws_security_group.logger.id}"]
  key_name = "${aws_key_pair.auth.id}"
  private_ip = "192.168.38.105"
  # Run the following commands to restart Fleet
  provisioner "remote-exec" {
    inline = [
      "cd /home/vagrant/kolide-quickstart && sudo docker-compose stop",
      "sudo service docker restart",
      "cd /home/vagrant/kolide-quickstart && sudo docker-compose start"
    ]
    connection {
      type = "ssh"
      user = "vagrant"
      password = "vagrant"
    }
  }
  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_instance" "dc" {
  instance_type = "t2.small"
  ami = "${var.dc_ami}"
  tags {
    Name = "dc.windomain.local"
  }
  subnet_id = "${aws_subnet.default.id}"
  vpc_security_group_ids = ["${aws_security_group.windows.id}"]
  private_ip = "192.168.38.102"
  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_instance" "wef" {
  instance_type = "t2.small"
  ami = "${var.wef_ami}"
  tags {
    Name = "wef.windomain.local"
  }
  subnet_id = "${aws_subnet.default.id}"
  vpc_security_group_ids = ["${aws_security_group.windows.id}"]
  private_ip = "192.168.38.103"
  root_block_device {
    delete_on_termination = true
  }
}

resource "aws_instance" "win10" {
  instance_type = "t2.small"
  ami = "${var.win10_ami}"
  tags {
    Name = "win10.windomain.local"
  }
  subnet_id = "${aws_subnet.default.id}"
  vpc_security_group_ids = ["${aws_security_group.windows.id}"]
  private_ip = "192.168.38.104"
  root_block_device {
    delete_on_termination = true
  }
}
