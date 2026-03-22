###############################################################################
# <vm-name>.tf  –  Template for adding a new VM to infrastructure/virtual-machines/
#
# Steps:
#   1. Copy this file to infrastructure/virtual-machines/<vm-name>.tf
#   2. Replace every occurrence of <vm-name> with the actual VM name
#   3. Adjust size, image, and networking values in the locals block
#   4. Add matching output blocks to outputs.tf
###############################################################################

locals {
  <vm_name> = {
    name                = "<vm-name>-${var.environment}"
    resource_group_name = "rg-<vm-name>-${var.environment}"
    vnet_name           = "vnet-<vm-name>-${var.environment}"
    vnet_address_space  = "10.x.0.0/16"   # choose a non-overlapping CIDR
    subnet_name         = "snet-vms"
    subnet_prefix       = "10.x.1.0/24"
    vm_size             = "Standard_B2s"
    os_type             = "Linux"          # or "Windows"
    image = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
    }
    os_disk_type            = "StandardSSD_LRS"
    admin_username          = "azureadmin"
    disable_password_auth   = true
    enable_system_identity  = false
    enable_boot_diagnostics = true
  }
}

resource "azurerm_resource_group" "<vm_name>" {
  name     = local.<vm_name>.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "<vm_name>" {
  name                = local.<vm_name>.vnet_name
  location            = azurerm_resource_group.<vm_name>.location
  resource_group_name = azurerm_resource_group.<vm_name>.name
  address_space       = [local.<vm_name>.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "<vm_name>" {
  name                 = local.<vm_name>.subnet_name
  resource_group_name  = azurerm_resource_group.<vm_name>.name
  virtual_network_name = azurerm_virtual_network.<vm_name>.name
  address_prefixes     = [local.<vm_name>.subnet_prefix]
}

# https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm
module "<vm_name>" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.15"

  resource_group_name = azurerm_resource_group.<vm_name>.name
  location            = azurerm_resource_group.<vm_name>.location
  name                = local.<vm_name>.name
  os_type             = local.<vm_name>.os_type
  sku_size            = local.<vm_name>.vm_size

  source_image_reference = {
    publisher = local.<vm_name>.image.publisher
    offer     = local.<vm_name>.image.offer
    sku       = local.<vm_name>.image.sku
    version   = "latest"
  }

  network_interfaces = {
    nic0 = {
      name = "${local.<vm_name>.name}-nic"
      ip_configurations = {
        ipconfig0 = {
          name                          = "ipconfig0"
          subnet_id                     = azurerm_subnet.<vm_name>.id
          private_ip_address_allocation = "Dynamic"
        }
      }
    }
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = local.<vm_name>.os_disk_type
  }

  admin_username                  = local.<vm_name>.admin_username
  generate_admin_password_or_key  = true
  disable_password_authentication = local.<vm_name>.disable_password_auth

  managed_identities = local.<vm_name>.enable_system_identity ? { system_assigned = true } : null
  boot_diagnostics   = local.<vm_name>.enable_boot_diagnostics ? {} : null

  tags             = var.tags
  enable_telemetry = true
}

# Add these blocks to outputs.tf:
#
# output "<vm_name>_id" {
#   description = "Resource ID of <vm-name>."
#   value       = module.<vm_name>.resource_id
# }
#
# output "<vm_name>_name" {
#   description = "Name of <vm-name>."
#   value       = module.<vm_name>.name
# }
#
# output "<vm_name>_private_ip" {
#   description = "Private IP address of <vm-name>."
#   value       = module.<vm_name>.network_interfaces["nic0"].private_ip_address
# }
