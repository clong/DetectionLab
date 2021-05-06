resource "azurerm_virtual_machine" "exchange" {
  name = "exchange.windomain.local"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name
  network_interface_ids = [azurerm_network_interface.exchange-nic[count.index].id]
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
      content      = file("${path.module}/files/FirstLogonCommands.xml")
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
  resource_group_name  = azurerm_resource_group.detectionlab.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.detectionlab-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.38.106"
    public_ip_address_id          = azurerm_public_ip.exchange-publicip[count.index].id
  }
}

resource "azurerm_public_ip" "exchange-publicip" {
  name                = "exchange-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.detectionlab.name
  allocation_method   = "Static"

  tags = {
    role = "exchange"
  }
}
