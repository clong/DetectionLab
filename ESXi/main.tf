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

#########################################
#  ESXI Guest resource
#########################################
resource "esxi_guest" "logger" {
  guest_name = "logger"
  disk_store = var.esxi_datastore
  guestos    = "ubuntu-64"

  boot_disk_type = "thin"

  memsize            = "4096"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "Ubuntu1804"

    provisioner "remote-exec" {
    inline = [
      "sudo ifconfig eth1 up || echo 'eth1 up'",
      "sudo ifconfig eth2 up || echo 'eth2 up'",
      "sudo route add default gw 192.168.76.1 || echo 'route exists'"
    ]

    connection {
      host        = self.ip_address
      type        = "ssh"
      user        = "vagrant"
      password    = "vagrant"
    }
  }
  # This is the network that bridges your host machine with the ESXi VM
  # If this interface doesn't provide connectivity, you will have to uncomment
  # the interface below and add a virtual network that does
  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "00:50:56:a3:b1:c2"
    nic_type        = "e1000"
  }
  # This is the local network that will be used for 192.168.38.x addressing
  network_interfaces {
    virtual_network = var.hostonly_network
    mac_address     = "00:50:56:a3:b1:c4"
    nic_type        = "e1000"
  }
  # OPTIONAL: Uncomment out this interface stanza if your vm_network doesn't 
  # provide internet access
  # network_interfaces {
  #  virtual_network = var.nat_network
  #  mac_address     = "00:50:56:a3:b1:c3"
  #  nic_type        = "e1000"
  # }
  guest_startup_timeout  = 45
  guest_shutdown_timeout = 30
}

resource "esxi_guest" "dc" {
  guest_name = "dc"
  disk_store = var.esxi_datastore
  guestos    = "windows9srv-64"

  boot_disk_type = "thin"
  boot_disk_size = "35"

  memsize            = "4096"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "WindowsServer2016"
  # This is the network that bridges your host machine with the ESXi VM
  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "00:50:56:a1:b1:c2"
    nic_type        = "e1000"
  }
  # This is the local network that will be used for 192.168.38.x addressing
  network_interfaces {
    virtual_network = var.hostonly_network
    mac_address     = "00:50:56:a1:b1:c4"
    nic_type        = "e1000"
  }
  guest_startup_timeout  = 45
  guest_shutdown_timeout = 30
}

resource "esxi_guest" "wef" {
  guest_name = "wef"
  disk_store = var.esxi_datastore
  guestos    = "windows9srv-64"

  boot_disk_type = "thin"
  boot_disk_size = "35"

  memsize            = "2048"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "WindowsServer2016"
  # This is the network that bridges your host machine with the ESXi VM
  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "00:50:56:a1:b2:c2"
    nic_type        = "e1000"
  }
  # This is the local network that will be used for 192.168.38.x addressing
  network_interfaces {
    virtual_network = var.hostonly_network
    mac_address     = "00:50:56:a1:b4:c4"
    nic_type        = "e1000"
  }
  guest_startup_timeout  = 45
  guest_shutdown_timeout = 30
}

resource "esxi_guest" "win10" {
  guest_name = "win10"
  disk_store = var.esxi_datastore
  guestos    = "windows9-64"

  boot_disk_type = "thin"
  boot_disk_size = "35"

  memsize            = "2048"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"
  clone_from_vm = "Windows10"
  # This is the network that bridges your host machine with the ESXi VM
  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "00:50:56:a2:b1:c2"
    nic_type        = "e1000"
  }
  # This is the local network that will be used for 192.168.38.x addressing
  network_interfaces {
    virtual_network = var.hostonly_network
    mac_address     = "00:50:56:a2:b1:c4"
    nic_type        = "e1000"
  }
  guest_startup_timeout  = 45
  guest_shutdown_timeout = 30
}
