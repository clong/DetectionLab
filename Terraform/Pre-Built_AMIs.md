# Method 2 - Use Pre-Built AMIs

This method uses Terraform to bring DetectionLab infrastructure online by using pre-built shared AMIs.

The supplied Terraform configuration can then be used to create EC2 instances and all requisite networking components.

## Prerequisites
* A machine to build DetectionLab with
* An AWS account
* An AWS user and access keys to use with the AWS CLI
* Optional but recommended: a separate user for Terraform

## Step by step guide

1. [Configure the AWS command line utility](https://docs.aws.amazon.com/polly/latest/dg/setup-aws-cli.html)
2. Copy the file at [/DetectionLab/Terraform/terraform.tfvars.example](./terraform.tfvars.example) to `/DetectionLab/Terraform/terraform.tfvars`
3. In `terraform.tfvars`, provide overrides for the variables specified in [variables.tf](./variables.tf)
4. From the `/DetectionLab/Terraform/` directory, run `terraform init` to setup the initial Terraform configuration
5. Run `terraform apply` to begin the provisioning process
