###############################################################################
# example-vm
#
# Reference VM configuration. Copy this file and rename it to add a new VM.
# All values specific to this VM are defined in the locals block below.
###############################################################################

locals {
  example_vm = {
    name                = "example-vm-${var.environment}"
    resource_group_name = "rg-example-vm-${var.environment}"
    vnet_name           = "vnet-example-vm-${var.environment}"
    vnet_address_space  = "10.0.0.0/16"
    subnet_name         = "snet-vms"
    subnet_prefix       = "10.0.1.0/24"
    vm_size             = "Standard_B2s"
    os_type             = "Linux"
    image = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
    }
    os_disk_type             = "StandardSSD_LRS"
    admin_username           = "azureadmin"
    disable_password_auth    = true
    enable_system_identity   = false
    enable_boot_diagnostics  = true
  }
}

resource "azurerm_resource_group" "example_vm" {
  name     = local.example_vm.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "example_vm" {
  name                = local.example_vm.vnet_name
  location            = azurerm_resource_group.example_vm.location
  resource_group_name = azurerm_resource_group.example_vm.name
  address_space       = [local.example_vm.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "example_vm" {
  name                 = local.example_vm.subnet_name
  resource_group_name  = azurerm_resource_group.example_vm.name
  virtual_network_name = azurerm_virtual_network.example_vm.name
  address_prefixes     = [local.example_vm.subnet_prefix]
}

# https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm
module "example_vm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.15"

  resource_group_name = azurerm_resource_group.example_vm.name
  location            = azurerm_resource_group.example_vm.location
  name                = local.example_vm.name
  os_type             = local.example_vm.os_type
  sku_size            = local.example_vm.vm_size

  source_image_reference = {
    publisher = local.example_vm.image.publisher
    offer     = local.example_vm.image.offer
    sku       = local.example_vm.image.sku
    version   = "latest"
  }

  network_interfaces = {
    nic0 = {
      name = "${local.example_vm.name}-nic"
      ip_configurations = {
        ipconfig0 = {
          name                          = "ipconfig0"
          subnet_id                     = azurerm_subnet.example_vm.id
          private_ip_address_allocation = "Dynamic"
        }
      }
    }
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = local.example_vm.os_disk_type
  }

  admin_username                  = local.example_vm.admin_username
  generate_admin_password_or_key  = true
  disable_password_authentication = local.example_vm.disable_password_auth

  managed_identities = local.example_vm.enable_system_identity ? { system_assigned = true } : null
  boot_diagnostics   = local.example_vm.enable_boot_diagnostics ? {} : null

  tags             = var.tags
  enable_telemetry = true
}
