# DetectionLab Terraform

### Method 1 - Pre-built AMIs

#### Estimated time to build: 30 minutes

As of March 2019, I am now sharing pre-built AMIs on the Amazon Marketplace. The code inside of main.tf uses Terraform data sources to determine the correct AMI ID and will use the pre-built AMIs by default.

Using this method, it should be possible to bring DetectionLab online in under 30 minutes.

The instructions for deploying DetectionLab in AWS using the pre-built AMIs are available here: [Pre-Built AMIs README](./Pre-Built_AMIs.md)

### Method 2 - Building the VMs locally and exporting them to AWS as AMIs

#### Estimated time to build: 3-4 hours

One method for spinning up DetectionLab in AWS is to begin by using Virtualbox or VMware to build DetectionLab locally. You can then use AWS's VM import capabilities to create AMIs based off of the virtual machines. Once that process is complete, the infrastructure can easily be spun up using a Terraform configuration file.

This method has the benefit of allowing users to customize the VMs before importing them to AWS.

The instructions for deploying DetectionLab in AWS via this method are available here: [Build Your Own AMIs README](./VM_to_AMIs.md)


### Current AMI Listing
| Region | Name | AMI-ID |
|--------|------|--------|
| us-west-1 | detectionlab-dc    | ami-03e2df055c632a0dd |
| us-west-1 | detectionlab-wef   | ami-03c82482c03a740c5 |
| us-west-1 | detectionlab-win10 | ami-0a4644e74768900f7 |
| us-east-1 | detectionlab-dc    | ami-0eba8a430eb9c0d92 |
| us-east-1 | detectionlab-wef   | ami-077981880d8b81b6b |
| us-east-1 | detectionlab-win10 | ami-0d1b75d4a41ff0e0a |
