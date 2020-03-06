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
#
#  This Guest VM is a clone of an existing Guest VM named "centos7" (must exist and
#  be powered off), located in the "Templates" resource pool.  vmtest02 will be powered
#  on by default by terraform.  The virtual network "VM Network", must already exist on
#  your esxi host!
#
# https://github.com/josenk/vagrant-vmware-esxi/wiki/VMware-ESXi-6.5-guestOS-types
resource "esxi_guest" "dc" {
  guest_name = "dc"
  disk_store = "datastore2"
  guestos    = "windows9srv-64"

  boot_disk_type = "thin"
  boot_disk_size = "35"

  memsize            = "2048"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"

  #  clone_from_vm uses ovftool to clone an existing Guest on your esxi host.  This example will clone a Guest VM named "centos7", located in the "Templates" resource pool.
  #  ovf_source uses ovftool to produce a clone from an ovf or vmx image. (typically produced using the ovf_tool).
  #    Basically clone_from_vm clones from sources on the esxi host and ovf_source clones from sources on your local hard disk or a URL.
  #    These two options are mutually exclusive.
  clone_from_vm = "WindowsServer2016"

  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "00:50:56:a1:b1:c2"
    nic_type        = "e1000"
  }
  network_interfaces {
    virtual_network = var.nat_network
    mac_address     = "00:50:56:a1:b1:c3"
    nic_type        = "e1000"
  }
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
  disk_store = "datastore2"
  guestos    = "windows9srv-64"

  boot_disk_type = "thin"
  boot_disk_size = "35"

  memsize            = "2048"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"

  #  clone_from_vm uses ovftool to clone an existing Guest on your esxi host.  This example will clone a Guest VM named "centos7", located in the "Templates" r$
  #  ovf_source uses ovftool to produce a clone from an ovf or vmx image. (typically produced using the ovf_tool).
  #    Basically clone_from_vm clones from sources on the esxi host and ovf_source clones from sources on your local hard disk or a URL.
  #    These two options are mutually exclusive.
  clone_from_vm = "WindowsServer2016"

  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "00:50:56:a1:b2:c2"
    nic_type        = "e1000"
  }
  network_interfaces {
    virtual_network = var.nat_network
    mac_address     = "00:50:56:a1:b3:c3"
    nic_type        = "e1000"
  }
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
  disk_store = "datastore2"
  guestos    = "windows9-64"

  boot_disk_type = "thin"
  boot_disk_size = "35"

  memsize            = "2048"
  numvcpus           = "2"
  resource_pool_name = "/"
  power              = "on"

  #  clone_from_vm uses ovftool to clone an existing Guest on your esxi host.  This example will clone a Guest VM named "centos7", located in the "Templates" r$
  #  ovf_source uses ovftool to produce a clone from an ovf or vmx image. (typically produced using the ovf_tool).
  #    Basically clone_from_vm clones from sources on the esxi host and ovf_source clones from sources on your local hard disk or a URL.
  #    These two options are mutually exclusive.
  clone_from_vm = "Windows10"

  network_interfaces {
    virtual_network = var.vm_network
    mac_address     = "00:50:56:a2:b1:c2"
    nic_type        = "e1000"
  }
  network_interfaces {
    virtual_network = var.nat_network
    mac_address     = "00:50:56:a2:b1:c3"
    nic_type        = "e1000"
  }
  network_interfaces {
    virtual_network = var.hostonly_network
    mac_address     = "00:50:56:a2:b1:c4"
    nic_type        = "e1000"
  }
  guest_startup_timeout  = 45
  guest_shutdown_timeout = 30
}
