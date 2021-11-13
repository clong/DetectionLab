# Prereqs (~30-60 minutes)

1. Have an Proxmox VE instance installed. This implementation was built and tested on Proxmox 7.x but may work with older versions of Proxmox.  
2. Terraform version 0.13 or higher is required as it provides support for installing Terraform providers directly from the Terraform Registry.  
3. The Proxmox Terraform Provider from Telmate https://github.com/Telmate/terraform-provider-proxmox is required, but will be installed automatically during a later step. Additional documentation for the providers is here: https://registry.terraform.io/providers/Telmate/proxmox/latest/docs.  
4. Your Proxmox instance must have at least two separate networks (Proxmox bridges). First network (vmbr0) that is accessible from your current machine and has internet connectivity and a second  HostOnly network (vmbr1) to allow the VMs to communicate over a private network. The vmbr0 network that provides DHCP and internet connectivity must also be reachable from your provisioning host that is running Terraform - ensure your firewall is configured to allow this.  
5. 
OVFTool must be installed and in your path.
On MacOS, I solved this by creating a symbolic link to the ovftool included in VMWare Fusion: sudo ln -s "/Applications/VMware Fusion.app/Contents/Library/VMware OVF Tool/ovftool" "/usr/local/bin/ovftool"
Downloads for OVFTool are also here: https://code.vmware.com/web/tool/4.4.0/ovf
On your ESXi instance, you must:
Enable SSH
Enable the “Guest IP Hack”
Open VNC ports on the firewall (not reqired for ESXi 7.0+)
Instructions for those steps are here: https://nickcharlton.net/posts/using-packer-esxi-6.html
Alternatively, you can install the VIB file from https://github.com/sukster/ESXi-Packer-VNC which will automatically open the VNC ports on the ESXi firewall.
Install Ansible and pywinrm via pip3 install ansible pywinrm --user or by creating and using a virtual environment.
Packer v1.6.3+ must be installed and in your PATH
sshpass must be installed to allow Ansible to use password login. On MacOS, install via brew install hudochenkov/sshpass/sshpass as brew install sshpass does not allow it to be installed.
