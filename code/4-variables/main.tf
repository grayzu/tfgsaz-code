terraform {
  required_version = ">= 0.12.5"
}

provider "azurerm" {
    version = ">= 1.32"
}

provider "random" {
    version = ">= 2.2"
}

# Get a random string for resource names created by this configuration,
# to avoid name conflicts with other tutorials, etc. 
resource "random_string" "morpheme" {
    length = 6
    special = false
    number = false
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
    name     = "${var.prefix}${random_string.morpheme.result}RG"
    location = var.location
    tags     = var.tags
}

# Create virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "${var.prefix}${random_string.morpheme.result}VNet"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    tags                = var.tags
}

# Create subnet
resource "azurerm_subnet" "subnet" {
    name                 = "${var.prefix}${random_string.morpheme.result}Subnet"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefix       = "10.0.1.0/24"
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
    name                         = "${var.prefix}${random_string.morpheme.result}PublicIP"
    location                     = var.location
    resource_group_name          = azurerm_resource_group.rg.name
    allocation_method            = "Dynamic"
    tags                         = var.tags
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
    name                = "${var.prefix}${random_string.morpheme.result}NSG"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
    tags                = var.tags

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
    name                      = "${var.prefix}${random_string.morpheme.result}NIC"
    location                  = var.location
    resource_group_name       = azurerm_resource_group.rg.name
    network_security_group_id = azurerm_network_security_group.nsg.id
    tags                      = var.tags

    ip_configuration {
        name                          = "${var.prefix}${random_string.morpheme.result}NICConfg"
        subnet_id                     = azurerm_subnet.subnet.id
        private_ip_address_allocation  = "dynamic"
        public_ip_address_id          = azurerm_public_ip.publicip.id
    }
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "vm" {
    name                  = "${var.prefix}${random_string.morpheme.result}VM"
    location              = var.location
    resource_group_name   = azurerm_resource_group.rg.name
    network_interface_ids = [azurerm_network_interface.nic.id]
    vm_size               = "Standard_B1s"
    tags                  = var.tags

    storage_os_disk {
        name              = "${var.prefix}${random_string.morpheme.result}OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = lookup(var.sku, var.location)
        version   = "latest"
    }

    os_profile {
        computer_name  = "${var.prefix}${random_string.morpheme.result}VM"
        admin_username = var.admin_username
        admin_password = var.admin_password
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

}

# Set output values

data "azurerm_public_ip" "pub-ip" {
    name = azurerm_public_ip.publicip.name
    resource_group_name = azurerm_resource_group.rg.name
}

output "public-ip-address" {
    value = data.azurerm_public_ip.pub-ip.ip_address
}

output "os-sku" {
    value = lookup(var.sku, var.location)
}
