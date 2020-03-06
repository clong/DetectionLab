# Building DetectionLab on ESXi

NOTE: This is a work in progress and provisioning is not yet functional. At this time here is what works:

* Building Packer Windows images on ESXi
* Bringing the Windows Images online using Terraform

## Prereqs
1. Install the [requirements from the ESXi Terraform Provider](https://github.com/josenk/terraform-provider-esxi#requirements)
2. Build and install the [terraform-provider-esxi](https://github.com/josenk/terraform-provider-esxi#building-the-provider) provider
3. Your ESXi must have at least two separate networks - one that is accessible from your host (VM Network) and a NAT network to allow the VMs to have internet access (NAT Network). Here's a decent guide to help you with the NAT network: https://medium.com/@glmdev/how-to-set-up-virtualized-pfsense-on-vmware-esxi-6-x-2c2861b25931

## Steps
1. Edit the following variables in `windows_10_esxi.json` and `windows_2016_esxi.json` to match your ESXi configuration:
  * remote_datastore
  * remote_host
  * remote_username
  * remote_password

2. From the ESXi directory, run `packer build windows_10_esxi.json` and `packer build windows_2016_esxi.json`. These can be run in parallel from two separate terminal sessions.
3. Once the Packer builds complete, ensure you now see Windows10 and WindowsServer2016 in your ESXi console
4. Edit the variables in `ESXi/variables.tf` to match your local ESXi configuration
5. Run `terraform init && terraform apply`

It takes quite some time for the linked clones to be created, but once they're finished, they should be accessible!

## Future work required
* The logger host needs to be implemented. This should be fairly straightforward.
* The provisioning for the Windows hosts needs to be figured out. I'm not sure if it makes more sense to build it all out in Packer and then just bring the VMs online using Terraform, or if it makes more sense to provision them using something like Ansible.

I'm completely open to any and all input here as this is not my area of expertise :) 
