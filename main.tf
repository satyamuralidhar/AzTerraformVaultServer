terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rsg" {
  name     = var.resource_group_name
  location = var.location

}

resource "azurerm_virtual_network" "vnet" {
  name                = "vault-vnet"
  location            = azurerm_resource_group.rsg.location
  resource_group_name = azurerm_resource_group.rsg.name
  address_space       = [var.address_space]

}

resource "azurerm_subnet" "subnet" {
  name                 = "vault-subnet"
  resource_group_name  = azurerm_resource_group.rsg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_prefixes]
}



resource "azurerm_public_ip" "vault-pip" {
  name                = "vault-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rsg.name
  allocation_method   = "Dynamic"

}

resource "azurerm_network_security_group" "vault-nsg" {
  name                = "vault-ssh"
  location            = var.location
  resource_group_name = azurerm_resource_group.rsg.name
  security_rule {
    name                       = "Inbound Vault"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8200"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Outbound Vault"
    priority                   = 106
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8200"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_rule" "ssh_access" {
  name                        = "ssh-access-rule"
  network_security_group_name = azurerm_network_security_group.vault-nsg.name
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 200
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.rsg.name
}



resource "azurerm_network_security_rule" "ssh_access_vault_demo" {
  name                        = "allow-vault-demo-ssh"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 210
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "22"
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.rsg.name
  network_security_group_name = azurerm_network_security_group.vault-nsg.name
}

resource "azurerm_network_interface" "vault-nic" {
  name                = "vault-demo-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rsg.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vault-pip.id
  }

}

resource "azurerm_network_interface_security_group_association" "nicassociation" {
  network_interface_id      = azurerm_network_interface.vault-nic.id
  network_security_group_id = azurerm_network_security_group.vault-nsg.id
}

resource "azurerm_subnet_network_security_group_association" "nsgassociation" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.vault-nsg.id
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
}

resource "null_resource" "save-key" {
  triggers = {
    key = tls_private_key.key.private_key_pem
  }

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p ${path.module}/.ssh
      echo "${tls_private_key.key.private_key_pem}" > ${path.module}/.ssh/id_rsa
      chmod 0600 ${path.module}/.ssh/id_rsa
EOF
  }
}

resource "azurerm_linux_virtual_machine" "vault-vm" {
  name                  = "vault-vm"
  location              = azurerm_virtual_network.vnet.location
  resource_group_name   = var.resource_group_name
  size                  = "Standard_B1s"
  admin_username        = var.user_name
  network_interface_ids = [azurerm_network_interface.vault-nic.id]

  admin_ssh_key {
    username   = var.user_name
    public_key = tls_private_key.key.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20.04-LTS"
    version   = "gen2"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  identity {
    type = "SystemAssigned"
  }

}

resource "null_resource" "shell" {
  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf vault-install*",
      "sudo wget https://gist.githubusercontent.com/satyamuralidhar/097f604fb3994b9a766e8425a2e810d6/raw/a98fc6e2a381b83f000647f3c026e478c2ebf191/vault-install.sh",
      "sudo chmod +x vault-install.sh",
      "sudo sh vault-install.sh"

    ]
    connection {
      type        = "ssh"
      user        = var.user_name
      private_key = tls_private_key.key.private_key_pem
      host        = azurerm_linux_virtual_machine.vault-vm.public_ip_address
    }
  }
}

# resource "azurerm_virtual_machine_extension" "vault-extension" {
#   name                 = "vault-demo-extension"
#   virtual_machine_id   = azurerm_virtual_machine.vault-vm.id
#   publisher            = "Microsoft.OSTCExtensions"
#   type                 = "CustomScriptForLinux"
#   type_handler_version = "1.2"

#   settings             = <<SETTINGS
#     {
#       "commandToExecute": "${var.cmd_extension}",
#        "fileUris": [
#         "${var.cmd_script}"
#        ]
#     }
# SETTINGS
# }

# Gets the current subscription id
data "azurerm_subscription" "primary" {}


data "azurerm_client_config" "clientconfig" {}

resource "azurerm_role_assignment" "roleassign" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Reader"
  principal_id         = lookup(azurerm_linux_virtual_machine.vault-vm.identity[0], "principal_id")
}

