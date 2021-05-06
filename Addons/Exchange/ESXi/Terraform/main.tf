#########################################
#  ESXI Provider host/login details
#########################################
#
#   Use of variables here to hide/move the variables to a separate file
#
provider "esxi" {
  esxi_hostname = var.esxi_hostname
  esxi_hostport = var.esxi_hostport
  esxi_username = var.esxi_username
  esxi_password = var.esxi_password
}

resource "esxi_guest" "exchange" {
  guest_name = "exchange"
  disk_store = var.esxi_datastore
  guestos    = "windows9srv-64"

  boot_disk_type = "thin"

  memsize            = "8192"
  numvcpus           = "4"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "WindowsServer2016"
  # This is the network that bridges your host machine with the ESXi VM
  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "00:50:56:a1:b2:c5"
    nic_type        = "e1000"
  }
  # This is the local network that will be used for 192.168.38.x addressing
  network_interfaces {
    virtual_network = var.hostonly_network
    mac_address     = "00:50:56:a1:b4:c5"
    nic_type        = "e1000"
  }
  guest_startup_timeout  = 45
  guest_shutdown_timeout = 30
}
