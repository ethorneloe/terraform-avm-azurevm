resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

# https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.8"

  name                = "vnet-${var.name}-${var.environment}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.config.vnet_address_space]
  enable_telemetry    = true

  subnets = {
    snet_vms = {
      name             = "snet-vms"
      address_prefixes = [var.config.subnet_prefix]
    }
  }
}

# https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm
module "vm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.15"

  name                = "${var.name}-${var.environment}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = var.config.os_type
  sku_size            = var.config.vm_size
  zone                = var.config.zone
  enable_telemetry    = true

  source_image_reference = {
    publisher = var.config.image.publisher
    offer     = var.config.image.offer
    sku       = var.config.image.sku
    version   = "latest"
  }

  network_interfaces = {
    nic0 = {
      name = "${var.name}-${var.environment}-nic"
      ip_configurations = {
        ipconfig0 = {
          name                          = "ipconfig0"
          private_ip_subnet_resource_id = module.vnet.subnets["snet_vms"].resource_id
        }
      }
    }
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = var.config.os_disk_type
  }

  admin_username                  = var.config.admin_username
  generate_admin_password_or_key  = true
  disable_password_authentication = var.config.disable_password_auth

  managed_identities = var.config.enable_system_identity ? { system_assigned = true } : null
  boot_diagnostics   = var.config.enable_boot_diagnostics ? {} : null

  tags = var.tags
}
