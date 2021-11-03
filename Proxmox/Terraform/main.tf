provider "proxmox" {
    pm_api_url = var.proxmox_api_url
    pm_user = var.proxmox_api_user
    pm_password = var.proxmox_api_password
    pm_tls_insecure = true
    pm_parallel = 4
}

resource "proxmox_vm_qemu" "logger" {
  name = "logger"
  target_node = var.proxmox_node
  clone = "Ubuntu2004"
  full_clone = true
  desc = "logger"
  cores = "2"
  sockets = "1"
  cpu = "host"
  memory = "4096"
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"
  agent = 1
  onboot = false

  disk {
    size = "64G"
    type = "scsi"
    storage = var.vm_disk
    cache = "writeback"
    format = "raw"
    discard = var.vm_disk_discard
  }

  # This is the network that bridges your host machine with the Proxmox VM
  network {
    model = "virtio"
    bridge = var.vm_network
    macaddr = "00:50:56:a3:b1:c2"
    firewall = false
  }

  # This is the local network that will be used for 192.168.56.x addressing
  network {
    model = "virtio"
    bridge = var.hostonly_network
    macaddr = "00:50:56:a3:b1:c4"
    firewall = false
  }

    connection {
      host = self.ssh_host
      type = "ssh"
      user = "vagrant"
      password = "vagrant"
    }

    provisioner "remote-exec" {
    inline = [
      "sudo ifconfig eth0 up && echo 'eth0 up' || echo 'unable to bring eth0 interface up",
      "sudo ifconfig eth1 up && echo 'eth1 up' || echo 'unable to bring eth1 interface up"
    ]
  }
}

resource "proxmox_vm_qemu" "dc" {
  name = "dc"
  target_node = var.proxmox_node
  clone = "WindowsServer2016"
  full_clone = true
  desc = "dc"
  cores = "2"
  sockets = "1"
  cpu = "host"
  memory = "4096"
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"
  agent = 1
  onboot = false

  disk {
    size = "64G"
    type = "scsi"
    storage = var.vm_disk
    cache = "writeback"
    format = "raw"
    discard = var.vm_disk_discard
  }

  # This is the network that bridges your host machine with the Proxmox VM
  network {
    model = "virtio"
    bridge = var.vm_network
    macaddr = "00:50:56:a1:b1:c2"
    firewall = false
  }

 # This is the local network that will be used for 192.168.56.x addressing
  network {
    model = "virtio"
    bridge = var.hostonly_network
    macaddr = "00:50:56:a1:b1:c4"
    firewall = false
  }
}

resource "proxmox_vm_qemu" "wef" {
  name = "wef"
  target_node = var.proxmox_node
  clone = "WindowsServer2016"
  full_clone = true
  desc = "wef"
  cores = "2"
  sockets = "1"
  cpu = "host"
  memory = "2048"
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"
  agent = 1
  onboot = false

  disk {
    size = "64G"
    type = "scsi"
    storage = var.vm_disk
    cache = "writeback"
    format = "raw"
    discard = var.vm_disk_discard
  }

  # This is the network that bridges your host machine with the Proxmox VM
  network {
    model = "virtio"
    bridge = var.vm_network
    macaddr = "00:50:56:a1:b2:c2"
    firewall = false
  }

 # This is the local network that will be used for 192.168.56.x addressing
  network {
    model = "virtio"
    bridge = var.hostonly_network
    macaddr = "00:50:56:a1:b4:c4"
    firewall = false
  }
}

resource "proxmox_vm_qemu" "win10" {
  name = "win10"
  target_node = var.proxmox_node
  clone = "Windows10"
  full_clone = true
  desc = "win10"
  cores = "2"
  sockets = "1"
  cpu = "host"
  memory = "2048"
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"
  agent = 1
  onboot = false

  disk {
    size = "64G"
    type = "scsi"
    storage = var.vm_disk
    cache = "writeback"
    format = "raw"
    discard = var.vm_disk_discard
  }

  # This is the network that bridges your host machine with the Proxmox VM
  network {
    model = "virtio"
    bridge = var.vm_network
    macaddr = "00:50:56:a2:b1:c2"
    firewall = false
  }

 # This is the local network that will be used for 192.168.56.x addressing
  network {
    model = "virtio"
    bridge = var.hostonly_network
    macaddr = "00:50:56:a2:b1:c4"
    firewall = false
  }
}