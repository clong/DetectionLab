# terraform init, plan, apply, destroy
# Note: does not support idempotence, don't execute twice with same scope.
# https://www.terraform.io/docs/providers/azurerm/index.html
# latest test: terraform 0.12.18
#
# FIXME!
# * apply: provisioning not working on Windows
# Error: Unsupported argument [...] An argument named "connection" is not expected here.
#    apply => Error: timeout - last error: SSH authentication failed (root@:22): ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], no supported methods remain
# * apply: linux provisioning
#	=> works but script ends with error code for some reason (post bro install and splunk restart)

# Specify the provider and access details
provider "azurerm" {
  features {}
}

# https://github.com/terraform-providers/terraform-provider-azurerm/blob/1940d84dba45e41b2f1f868a22d7f7af1adea8a0/examples/virtual-machines/virtual_machine/vm-joined-to-active-directory/modules/active-directory/2-virtual-machine.tf
locals {
    custom_data_content  = file("${path.module}/files/winrm.ps1")
}

resource "azurerm_resource_group" "detectionlab" {
  name = "DetectionLab-terraform"
  location = var.region
}

resource "azurerm_virtual_network" "detectionlab-network" {
  name = "DetectionLab-vnet"
  address_space = ["192.168.0.0/16"]
  location = var.region
  resource_group_name = azurerm_resource_group.detectionlab.name
}

# Create a subnet to launch our instances into
resource "azurerm_subnet" "detectionlab-subnet" {
  name                 = "DetectionLab-Subnet"
  resource_group_name  = azurerm_resource_group.detectionlab.name
  virtual_network_name = azurerm_virtual_network.detectionlab-network.name
  address_prefixes       = ["192.168.56.0/24"]
}

resource "azurerm_network_security_group" "detectionlab-nsg" {
  name                = "DetectionLab-nsg"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name

  # SSH access
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    # source_address_prefix      = "*"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Splunk access
  security_rule {
    name                       = "Splunk"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Fleet access
  security_rule {
    name                       = "Fleet"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8412"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # RDP
  security_rule {
    name                       = "RDP"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # WinRM
  security_rule {
    name                       = "WinRM"
    priority                   = 1005
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985-5986"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Windows ATA
  security_rule {
    name                       = "WindowsATA"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Allow all traffic from the private subnet
  security_rule {
    name                       = "PrivateSubnet"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "192.168.56.0/24"
    destination_address_prefix = "*"
  }

  # Guacamole access
  security_rule {
    name                       = "Guacamole"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }

  # Velociraptor access
  security_rule {
    name                       = "Velociraptor"
    priority                   = 1009
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9999"
    source_address_prefixes    = var.ip_whitelist
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "detectionlab-nsga" {
  subnet_id                 = azurerm_subnet.detectionlab-subnet.id
  network_security_group_id = azurerm_network_security_group.detectionlab-nsg.id
}

resource "azurerm_public_ip" "logger-publicip" {
  name                = "logger-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.detectionlab.name
  allocation_method   = "Static"

  tags = {
    role = "logger"
  }
}

resource "azurerm_network_interface" "logger-nic" {
  name                = "logger-nic"
  location            = var.region
  resource_group_name = azurerm_resource_group.detectionlab.name

  ip_configuration {
    name                          = "logger-NicConfiguration"
    subnet_id                     = azurerm_subnet.detectionlab-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.56.105"
    public_ip_address_id          = azurerm_public_ip.logger-publicip.id
  }
}

# Storage
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group_name  = azurerm_resource_group.detectionlab.name
  }
  byte_length = 8
}

resource "azurerm_storage_account" "detectionlab-storageaccount" {
  name                = "diag${random_id.randomId.hex}"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name
  account_replication_type = "LRS"
  account_tier = "Standard"
  min_tls_version = "TLS1_2"
}

# Linux VM
resource "azurerm_virtual_machine" "logger" {
  name = "logger"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name
  network_interface_ids = [azurerm_network_interface.logger-nic.id]
  vm_size               = "Standard_DS1_v2"

  delete_os_disk_on_termination = true

  storage_os_disk {
    name              = "OsDiskLogger"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  os_profile {
    computer_name  = "logger"
    admin_username = "vagrant"
    admin_password = "vagrant"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/vagrant/.ssh/authorized_keys"
      key_data = file(var.public_key_path)
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = azurerm_storage_account.detectionlab-storageaccount.primary_blob_endpoint
  }

  # Provision
  # https://github.com/terraform-providers/terraform-provider-azurerm/blob/master/examples/virtual-machines/provisioners/linux/main.tf
  # https://www.terraform.io/docs/provisioners/connection.html
  provisioner "remote-exec" {
    connection {
      host = azurerm_public_ip.logger-publicip.ip_address
      user     = "vagrant"
      private_key = file(var.private_key_path)
    }
    inline = [
      "sudo add-apt-repository universe && sudo apt-get -qq update && sudo apt-get -qq install -y git",
      "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config && sudo service ssh restart",
      "echo 'logger' | sudo tee /etc/hostname && sudo hostnamectl set-hostname logger",
      "sudo adduser --disabled-password --gecos \"\" vagrant && echo 'vagrant:vagrant' | sudo chpasswd",
      "echo 'vagrant:vagrant' | sudo chpasswd",
      "sudo mkdir /home/vagrant/.ssh && sudo cp /home/ubuntu/.ssh/authorized_keys /home/vagrant/.ssh/authorized_keys && sudo chown -R vagrant:vagrant /home/vagrant/.ssh",
      "echo 'vagrant    ALL=(ALL:ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers",
      "sudo git clone https://github.com/clong/DetectionLab.git /opt/DetectionLab",
      "sudo sed -i 's/eth1/eth0/g' /opt/DetectionLab/Vagrant/logger_bootstrap.sh",
      "sudo sed -i 's/ETH1/ETH0/g' /opt/DetectionLab/Vagrant/logger_bootstrap.sh",
      "sudo sed -i 's#/usr/local/go/bin/go get -u#GOPATH=/root/go /usr/local/go/bin/go get -u#g' /opt/DetectionLab/Vagrant/logger_bootstrap.sh",
      "sudo sed -i 's#/vagrant/resources#/opt/DetectionLab/Vagrant/resources#g' /opt/DetectionLab/Vagrant/logger_bootstrap.sh",
      "sudo chmod +x /opt/DetectionLab/Vagrant/logger_bootstrap.sh",
      "sudo apt-get -qq update",
      "sudo /opt/DetectionLab/Vagrant/logger_bootstrap.sh 2>&1 |sudo tee /opt/DetectionLab/Vagrant/bootstrap.log",
    ]
  }

  tags = {
    role = "logger"
  }
}
# Uncomment the following lines if you want to use Azure Log Analytics and Azure Sentinel
/*
resource "azurerm_virtual_machine_extension" "mmaagent-logger" {
  name                 = "${azurerm_virtual_machine.logger.name}-mma"
  virtual_machine_id   = azurerm_virtual_machine.logger.id
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "OmsAgentForLinux"
  type_handler_version = "1.13"
  auto_upgrade_minor_version = "true"

  settings = <<SETTINGS
    {
      "workspaceId": "${var.workspaceId}"
    }
SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
   {
      "workspaceKey": "${var.workspaceKey}"
   }
PROTECTED_SETTINGS
}
*/

# https://github.com/terraform-providers/terraform-provider-azurerm/tree/master/examples/virtual-machines/vm-joined-to-active-directory

# Windows VM
resource "azurerm_network_interface" "dc-nic" {
  name = "dc-nic"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name

  ip_configuration {
    name                          = "DC-NicConfiguration"
    subnet_id                     = azurerm_subnet.detectionlab-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.56.102"
    public_ip_address_id          = azurerm_public_ip.dc-publicip.id
  }
}

resource "azurerm_public_ip" "dc-publicip" {
  name                = "dc-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.detectionlab.name
  allocation_method   = "Static"

  tags = {
    role = "dc"
  }
}

resource "azurerm_network_interface" "wef-nic" {
  name = "wef-nic"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name

  ip_configuration {
    name                          = "WEF-NicConfiguration"
    subnet_id                     = azurerm_subnet.detectionlab-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.56.103"
    public_ip_address_id          = azurerm_public_ip.wef-publicip.id
  }
}

resource "azurerm_public_ip" "wef-publicip" {
  name                = "wef-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.detectionlab.name
  allocation_method   = "Static"

  tags = {
    role = "wef"
  }
}

resource "azurerm_network_interface" "win10-nic" {
  name = "win10-nic"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.detectionlab-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "192.168.56.104"
    public_ip_address_id          = azurerm_public_ip.win10-publicip.id
  }
}

resource "azurerm_public_ip" "win10-publicip" {
  name                = "win10-public-ip"
  location            = var.region
  resource_group_name = azurerm_resource_group.detectionlab.name
  allocation_method   = "Static"

  tags = {
    role = "win10"
  }
}

resource "azurerm_virtual_machine" "dc" {
  name = "dc.windomain.local"
  location = var.region
  resource_group_name   = azurerm_resource_group.detectionlab.name
  network_interface_ids = [azurerm_network_interface.dc-nic.id]
  vm_size               = "Standard_D1_v2"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = "dc"
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
    name              = "OsDiskDc"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  tags = {
    role = "dc"
  }
}
# Uncomment the following lines if you want to use Azure Log Analytics and Azure Sentinel
/*
resource "azurerm_virtual_machine_extension" "dc" {
  name                 = "${azurerm_virtual_machine.dc.name}-mma"
  virtual_machine_id   = azurerm_virtual_machine.dc.id
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "MicrosoftMonitoringAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = "true"

  settings = <<SETTINGS
    {
      "workspaceId": "${var.workspaceId}"
    }
SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
   {
      "workspaceKey": "${var.workspaceKey}"
   }
PROTECTED_SETTINGS
}
*/

resource "azurerm_virtual_machine" "wef" {
  name = "wef.windomain.local"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name
  network_interface_ids = [azurerm_network_interface.wef-nic.id]
  vm_size               = "Standard_D1_v2"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  os_profile {
    computer_name  = "wef"
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
    name              = "OsDiskWef"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  tags = {
    role = "wef"
  }
}

# Uncomment the following lines if you want to use Azure Log Analytics and Azure Sentinel
/*
resource "azurerm_virtual_machine_extension" "mmaagent-Wef" {
  name                 = "${azurerm_virtual_machine.wef.name}-mma"
  virtual_machine_id   = azurerm_virtual_machine.wef.id
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "MicrosoftMonitoringAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = "true"

  settings = <<SETTINGS
    {
      "workspaceId": "${var.workspaceId}"
    }
SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
   {
      "workspaceKey": "${var.workspaceKey}"
   }
PROTECTED_SETTINGS
}
*/

resource "azurerm_virtual_machine" "win10" {
  name = "win10.windomain.local"
  location = var.region
  resource_group_name  = azurerm_resource_group.detectionlab.name
  network_interface_ids = [azurerm_network_interface.win10-nic.id]
  vm_size               = "Standard_D1_v2"

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "19h1-pron"
    version   = "latest"
  }

  os_profile {
    computer_name  = "win10"
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
    name              = "OsDiskWin10"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  tags = {
    role = "win10"
  }
}

# Creation of the Ansible Inventory
data "template_file" "inventory" {
  template = "${file("../Ansible/inventory.tmpl")}"
  depends_on = [
    azurerm_public_ip.dc-publicip,
    azurerm_public_ip.wef-publicip,
    azurerm_public_ip.win10-publicip
  ]
  
  vars = {
    dc_public_ip = azurerm_public_ip.dc-publicip.ip_address
    wef_public_ip = azurerm_public_ip.wef-publicip.ip_address
    win10_public_ip = azurerm_public_ip.win10-publicip.ip_address
  }
}

resource "null_resource" "inventory-creation" {
  triggers = {
    template_rendered = "${data.template_file.inventory.rendered}"
  }
  provisioner "local-exec" {
    command = "echo '${data.template_file.inventory.rendered}' > ../Ansible/inventory.yml"
  }
}

# Uncomment the following lines if you want to use Azure Log Analytics and Azure Sentinel
/*
resource "azurerm_virtual_machine_extension" "mmaagent-Win10" {
  name                 = "${azurerm_virtual_machine.win10.name}-mma"
  virtual_machine_id   = azurerm_virtual_machine.win10.id
  publisher            = "Microsoft.EnterpriseCloud.Monitoring"
  type                 = "MicrosoftMonitoringAgent"
  type_handler_version = "1.0"
  auto_upgrade_minor_version = "true"

  settings = <<SETTINGS
    {
      "workspaceId": "${var.workspaceId}"
    }
SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
   {
      "workspaceKey": "${var.workspaceKey}"
   }
PROTECTED_SETTINGS
}
*/
