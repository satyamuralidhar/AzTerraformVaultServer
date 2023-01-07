variable "location" {}

variable "resource_group_name" {}

variable "address_space" {}

variable "sg_name" {
  default = "vault-demo"
}

variable "subnet_prefixes" {}


## Provisioning script variables

variable "cmd_extension" {
  description = "Command to be excuted by the custom script extension"
  default     = "sh vault-install.sh"
}

variable "cmd_script" {
  description = "Script to download which can be executed by the custom script extension"
  default     = "https://gist.githubusercontent.com/satyamuralidhar/097f604fb3994b9a766e8425a2e810d6/raw/f5cd3fa5f1a4ac1a38226732ed742dffc9939cb7/vault-install.sh"
}

variable "user_name" {}