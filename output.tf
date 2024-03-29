output "vault-demo_public_ip" {
  description = "public IP address of the vault-demo server"
  value       = azurerm_public_ip.vault-pip.ip_address
}

output "vault-demo_private_ip" {
  description = "private IP address of the vault-demo server"
  value       = azurerm_network_interface.vault-nic.private_ip_address
}

output "vault-demo_ssh" {
  description = "shortcut to ssh into the vault demo vm."
  value       = "ssh ${var.user_name}@${azurerm_public_ip.vault-pip.ip_address} -i ${path.module}/.ssh/id_rsa -L 8200:${azurerm_public_ip.vault-pip.ip_address}:8200"
}