variable "security_group_id" {
  type = list(string)
}

variable "subnet_id" {
  type = string
}

variable "instance_name_prefix" {
  type = string
}

variable "region" {
  type    = string
  default = ""
}

variable "custom-tags" {
  type = map(string)
  description = "Optional mapping for additional tags to apply to all related AWS resources"
  default = {}
}

variable "exchange_ami" {
  type    = string
  default = ""
}

# Use Data Sources to resolve the AMI-ID for the pre-built EXCHANGE host
data "aws_ami" "exchange_ami" {
  owners      = ["505638924199"]
  most_recent = true

  filter {
    name   = "name"
    values = ["detectionlab-exchange"]
  }
}