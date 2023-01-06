terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
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
  name                      = "vault-demo-nic"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rsg.name

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.vault-pip.id
  }

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

resource "azurerm_virtual_machine" "vault-vm" {
  name                          = "vault-vm"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.rsg.name
  network_interface_ids         = ["${azurerm_network_interface.vault-nic.id}"]
  vm_size                       = "Standard_DS1_v2"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "vault-demo-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vault-demo"
    admin_username = "azureuser"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/azureuser/.ssh/authorized_keys"
      key_data = "${trimspace(tls_private_key.key.public_key_openssh)} user@vaultdemo.io"
    }
  }

  identity = {
    type = "SystemAssigned"
  }

}

resource "azurerm_virtual_machine_extension" "vault-extension" {
  name                 = "vault-demo-extension"
  location             = var.location
  resource_group_name  = azurerm_resource_group.rsg.name
  virtual_machine_name = azurerm_virtual_machine.vault-vm.name
  publisher            = "Microsoft.OSTCExtensions"
  type                 = "CustomScriptForLinux"
  type_handler_version = "1.2"

  settings = <<SETTINGS
    {
      "commandToExecute": "${var.cmd_extension}",
       "fileUris": [
        "${var.cmd_script}"
       ]
    }
SETTINGS
}

# Gets the current subscription id
data "azurerm_subscription" "primary" {}

resource "azurerm_role_assignment" "vault-demo" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Reader"
  principal_id         = lookup(azurerm_virtual_machine.vault-vm.identity[0], "principal_id")
}

