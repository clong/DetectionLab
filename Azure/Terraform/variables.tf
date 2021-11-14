variable "region" {
  default = "West US 2"
}

variable "profile" {
  default = "terraform"
}

variable "availability_zone" {
  description = "https://docs.microsoft.com/en-us/azure/availability-zones/az-overview"
  default     = ""
}

variable "public_key_name" {
  description = "A name for SSH Keypair to use to auth to logger. Can be anything you specify."
  default     = "id_logger"
}

variable "public_key_path" {
  description = "Path to the public key to be loaded into the logger authorized_keys file"
  type        = string
  default     = "/home/user/.ssh/id_logger.pub"
}

# Note: must use ssh key without passphrase. not supported by Terraform.
variable "private_key_path" {
  description = "Path to the private key to use to authenticate to logger."
  type        = string
  default     = "/home/user/.ssh/id_logger"
}

variable "ip_whitelist" {
  description = "A list of CIDRs that will be allowed to access the instances"
  type        = list(string)
  default     = [""]
}

variable "external_dns_servers" {
  description = "Configure lab to allow external DNS resolution"
  type        = list(string)
  default     = ["8.8.8.8"]
}

variable "workspaceKey" {
  description = "WorkspaceKey of the Log Analytics workspace"
  type        = string
  default     = ""
}

variable "workspaceId" {
  description = "WorkspaceID of the log Analytics workspace"
  type        = string
  default     = ""
}

