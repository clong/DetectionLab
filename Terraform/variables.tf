variable "region" {
  default = "us-west-1"
}

variable "profile" {
  default = "terraform"
}

variable "availability_zone" {
  description = "https://www.terraform.io/docs/providers/aws/d/availability_zone.html"
  default     = ""
}

variable "shared_credentials_file" {
  description = "Path to your AWS credentials file"
  type        = string
  default     = "/home/username/.aws/credentials"
}

variable "public_key_name" {
  description = "A name for AWS Keypair to use to auth to logger. Can be anything you specify."
  default     = "id_logger"
}

variable "public_key_path" {
  description = "Path to the public key to be loaded into the logger authorized_keys file"
  type        = string
  default     = "/home/username/.ssh/id_logger.pub"
}

variable "private_key_path" {
  description = "Path to the private key to use to authenticate to logger."
  type        = string
  default     = "/home/username/.ssh/id_logger"
}

variable "ip_whitelist" {
  description = "A list of CIDRs that will be allowed to access the EC2 instances"
  type        = list(string)
  default     = [""]
}

variable "external_dns_servers" {
  description = "Configure lab to allow external DNS resolution"
  type        = list(string)
  default     = ["8.8.8.8"]
}

# Use Data Sources to resolve the AMI-ID for the Ubuntu 16.04 AMI
data "aws_ami" "logger_ami" {
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-20180912"]
  }
}

# Use Data Sources to resolve the AMI-ID for the pre-built DC host
data "aws_ami" "dc_ami" {
  owners = ["505638924199"]

  filter {
    name   = "name"
    values = ["detectionlab-dc"]
  }
}

# Use Data Sources to resolve the AMI-ID for the pre-built WEF host
data "aws_ami" "wef_ami" {
  owners      = ["505638924199"]
  most_recent = true

  filter {
    name   = "name"
    values = ["detectionlab-wef"]
  }
}

# Use Data Sources to resolve the AMI-ID for the pre-built Win10 host
data "aws_ami" "win10_ami" {
  owners      = ["505638924199"]
  most_recent = true

  filter {
    name   = "name"
    values = ["detectionlab-win10"]
  }
}

# If you are building your own AMIs, replace the default values below with
# the AMI IDs
variable "logger_ami" {
  type    = string
  default = ""
}

variable "dc_ami" {
  type    = string
  default = ""
}

variable "wef_ami" {
  type    = string
  default = ""
}

variable "win10_ami" {
  type    = string
  default = ""
}

