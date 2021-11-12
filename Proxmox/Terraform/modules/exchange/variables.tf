variable "proxmox_node" {
  default = "pve"
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