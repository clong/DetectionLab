# https://github.com/terraform-providers/terraform-provider-azurerm/blob/1940d84dba45e41b2f1f868a22d7f7af1adea8a0/examples/virtual-machines/virtual_machine/vm-joined-to-active-directory/modules/active-directory/2-virtual-machine.tf
locals {
    custom_data_content  = file("${path.module}/../../files/winrm.ps1")
}

provider "azurerm" {
  version = ">=2.93.0"
  features {}
}

resource "azurerm_virtual_machine" "exchange" {
  name = "exchange.windomain.local"
  location = var.region
  resource_group_name  = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.exchange-nic.id]
  vm_size               = "Standard_D3_v2"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = "exchange"
    admin_username = "vagrant"
    admin_password = "Vagrant123"
    custom_data    = local.custom_data_content
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = false

    # Auto-Login's required to configure WinRM
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>Vagrant123</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>vagrant</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    # https://github.com/terraform-providers/terraform-provider-azurerm/blob/master/examples/virtual-machines/provisioners/windows/files/FirstLogonCommands.xml
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = file("${path.module}/../../files/FirstLogonCommands.xml")
    }
  }

  storage_os_disk {
    name              = "OsDiskExchange"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  tags = {
    role = "exchange"
  }
}

resource "azurerm_network_interface" "exchange-nic" {
  name = "exchange-nic"
  location = var.region
  resource_group_name  = var.resource_group_name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.56.106"
    public_ip_address_id          = azurerm_public_ip.exchange-publicip.id
  }
}

resource "azurerm_public_ip" "exchange-publicip" {
  name                = "exchange-public-ip"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"

  tags = {
    role = "exchange"
  }
}
