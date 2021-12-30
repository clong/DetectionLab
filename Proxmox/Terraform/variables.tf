#
#  See https://www.terraform.io/intro/getting-started/variables.html for more details.
#
#  Don't change the variables in this file! 
#  Instead, create a terrform.tfvars file to override them.

variable "proxmox_api_url" {
  default = "https://192.168.1.1:8006/api2/json"
}

variable "proxmox_node" {
  default = "pve"
}

variable "proxmox_api_user" {
  default = "root@pam"
}

variable "proxmox_api_password" { # Unspecified will prompt
}

variable "vm_disk" {
  default = "local-lvm"
}

variable "vm_disk_discard" {
  default = "on" # For SSD disks use "on" but for other disks use "ignore"
}

variable "vm_network" {
  default = "vmbr0"
}

variable "hostonly_network" {
  default = "vmbr1"
}