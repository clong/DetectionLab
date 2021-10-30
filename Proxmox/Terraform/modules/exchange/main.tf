terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.0"
    }
  }
}

resource "proxmox_vm_qemu" "exchange" {
  name = "exchange"
  target_node = var.proxmox_node
  clone = "WindowsServer2016"
  full_clone = true
  desc = "exchange"
  cores = "4"
  sockets = "1"
  cpu = "kvm64"
  memory = "8192"
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

  network {
    model = "virtio"
    bridge = var.vm_network
    macaddr = "00:50:56:a1:b2:c5"
    firewall = false
  }

  network {
    model = "virtio"
    bridge = var.hostonly_network
    macaddr = "00:50:56:a1:b4:c5"
    firewall = false
  }
}