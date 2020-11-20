#
#  See https://www.terraform.io/intro/getting-started/variables.html for more details.
#
#  Change these defaults to fit your needs!

variable "esxi_hostname" {
  default = ""
}

variable "esxi_hostport" {
  default = "22"
}

variable "esxi_username" {
  default = "root"
}

variable "esxi_password" { # Unspecified will prompt
}

variable "esxi_datastore" {
  default = "datastore1"
}

variable "vm_network" {
  default = "VM Network"
}

variable "hostonly_network" {
  default = "HostOnly Network"
}
