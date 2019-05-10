# Method 1 - Use Pre-Built AMIs

This method uses Terraform to bring DetectionLab infrastructure online by using pre-built shared AMIs.

The supplied Terraform configuration can then be used to create EC2 instances and all requisite networking components.

## Prerequisites
* A system with Terraform, AWS CLI and git installed
* An AWS account
* AWS credentials for Terraform

## Step by step guide

1. Ensure the prerequisites are installed:
  * [Terraform](https://www.terraform.io/downloads.html)
  * [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
  * [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
2. [Configure the AWS command line utility](https://docs.aws.amazon.com/polly/latest/dg/setup-aws-cli.html) and set up a user for Terraform via `aws configure --profile terraform`.
3. Create a private/public keypair to use to SSH into logger: `ssh-keygen -b 2048 -f ~/.ssh/id_logger`
4. Copy the file at [/DetectionLab/Terraform/terraform.tfvars.example](./terraform.tfvars.example) to `/DetectionLab/Terraform/terraform.tfvars`
5. In `terraform.tfvars`, provide overrides for the variables specified in [variables.tf](./variables.tf)
6. From the `/DetectionLab/Terraform` directory, run `terraform init` to setup the initial Terraform configuration
7. Run `terraform apply` to begin the provisioning process

[![DetectionLab - Terraform](https://i.vimeocdn.com/video/777172792_640.webp)](https://vimeo.com/331695321)
