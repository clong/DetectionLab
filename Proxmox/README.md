# Prereqs (~30-60 minutes)

1. Have an Proxmox VE instance installed. This implementation was built and tested on Proxmox 7.x but may work with older versions of Proxmox.  
2. Terraform version 0.13 or higher is required as it provides support for installing Terraform providers directly from the Terraform Registry.  
3. The Proxmox Terraform Provider from Telmate https://github.com/Telmate/terraform-provider-proxmox is required, but will be installed automatically during a later step. For additional customization, the documentation for the provider is here: https://registry.terraform.io/providers/Telmate/proxmox/latest/docs/resources/vm_qemu.  
4. Your Proxmox instance must have at least two separate networks connected by bridges. First network (vmbr0) that is accessible from your current machine and has internet connectivity and a second HostOnly network (vmbr1) to allow the VMs to communicate over a private network. The network connected to vmbr0 that provides DHCP and internet connectivity must also be reachable from the host that is running Terraform - ensure your firewall is configured to allow this.  
5. Install Ansible and pywinrm via pip3 install ansible pywinrm --user or by creating and using a virtual environment.  
6. Packer v1.6.3+ must be installed and in your PATH  
7. sshpass must be installed to allow Ansible to use password login. On MacOS, install via brew install hudochenkov/sshpass/sshpass as brew install sshpass does not allow it to be installed.

# Steps

1. **(5 Minutes)** Edit the variables in DetectionLab/Proxmox/Packer/variables.json to match your Proxmox configuration. The esxi_network_with_dhcp_and_internet variable refers to any Proxmox network that will be able to provide DHCP and internet access to the VM while it’s being built in Packer. The provisioning_machine_ip variable refers to the IP address of your provisioning host.  
2. **(45 Minutes)** From the DetectionLab/Proxmox/Packer directory, run:
- PACKER_CACHE_DIR=../../Packer/packer_cache packer build -var-file variables.json windows_10_proxmox.json
- PACKER_CACHE_DIR=../../Packer/packer_cache packer build -var-file variables.json windows_2016_proxmox.json
- PACKER_CACHE_DIR=../../Packer/packer_cache packer build -var-file variables.json ubuntu2004_proxmox.json

  These commands can be run in parallel from three separate terminal sessions.

3. **(1 Minute)** Once the Packer builds finish, verify that you now see Windows10, WindowsServer2016, and Ubuntu2004 in your Proxmox console.  
4. **(5 Minutes)** In DetectionLab/Proxmox/Terraform, create a terraform.tfvars file (RECOMMENDED) to override the default variables listed in variables.tf.  
5. **(25 Minutes)** From DetectionLab/Proxmox, run **terraform init**. The Proxmox Terraform provider should install automatically during this step.  
6. Running **terraform apply** should then prompt us to create the logger, dc, wef, and win10 instances. Once finished, you should see the Terraform output with IP addresses of your VMs.  
7. Once Terraform has finished bringing the hosts online, change your directory to DetectionLab/Proxmox/Ansible.  
8. **(1 Minute)** Edit DetectionLab/Proxmox/Ansible/inventory.yml and replace the IP Addresses with the respective IP Addresses of your Proxmox VMs. At times, the Terraform output is unable to derive the IP address of hosts, so you may have to log into the Proxmox console to find that information and then enter the IP addresses into inventory.yml
