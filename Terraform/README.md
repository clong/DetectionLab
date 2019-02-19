# DetectionLab Terraform

When I considered the possible ways of building DetectionLab using Terraform, two possibilities came to mind:

### Method 1 - Building locally and exporting VMs
The general concept behind this method is to use Virtualbox or VMware to build DetectionLab. You can then use AWS's VM import capabilities to create AMIs based off of the virtual machines. Once that process is complete, the infrastructure can easily be spun up using a Terraform configuration file.

This method has the benefit of allowing users to customize the VMs before importing them to AWS.

The obvious downside is that it still requires local infrastructure to build the lab, and uploading large OVA files to S3 can be extremely time consuming on slower connections.

### Method 2 - Building and deploying in AWS
The alternative to building locally would be to build the lab entirely in AWS. This would mean the Packer builds would need to be modified to generate EBS volumes and the Vagrant provisioning would need to be modified to support cloud infrastructure. Virtualbox and VMware-based builds benefit from things like virtual machine guest tools for file sharing, which are obviously unavailable on AWS instances.

This method has the benefit of not requiring any local infrastructure for builds but requires a lot of work, cost, and time to convert the build process to be cloud-based.

### Progress Updates

The instructions for deploying DetectionLab to AWS via Method 1 are available here: [Method 1 README](./Method1/Method1.md)

Progress on Method 2 will be tracked using a GitHub project that is viewable here: https://github.com/clong/DetectionLab/projects/1
