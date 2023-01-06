variable "location" {}

variable "resource_group_name" {}

variable "address_space" {}

variable "sg_name" {
  default = "vault-demo"
}

variable "subnet_prefixes" {}

variable "subnet_names" {
  default = ["azure-vault-demo-public-subnet", "azure-vault-demo-private-subnet"]
}

## Provisioning script variables

variable "cmd_extension" {
  description = "Command to be excuted by the custom script extension"
  default     = "sh vault-install.sh"
}

variable "cmd_script" {
  description = "Script to download which can be executed by the custom script extension"
  #default     = "https://gist.githubusercontent.com/anubhavmishra/0b6eb19f38e63bb2eb9d459fd1c53b1d/raw/696eea84b8d12cd099c283439c2c412ae13d308d/vault-install.sh"
}
