locals {
  rg_name = var.resource_group_name != null ? var.resource_group_name : azurerm_resource_group.this[0].name
  rg_id   = var.resource_group_name != null ? data.azurerm_resource_group.this[0].id : azurerm_resource_group.this[0].id
}

resource "azurerm_resource_group" "this" {
  count    = var.resource_group_name == null ? 1 : 0
  name     = "rg-${var.name}-${var.environment}"
  location = var.location
  tags     = var.tags
}

data "azurerm_resource_group" "this" {
  count = var.resource_group_name != null ? 1 : 0
  name  = var.resource_group_name
}

# https://registry.terraform.io/modules/Azure/avm-res-network-networksecuritygroup/azurerm
module "nsg" {
  count = var.config.enable_public_ip ? 1 : 0

  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "~> 0.5"

  name                = "nsg-${var.name}-${var.environment}"
  location            = var.location
  resource_group_name = local.rg_name
  enable_telemetry    = true

  security_rules = {
    allow_inbound = {
      access                     = "Allow"
      direction                  = "Inbound"
      name                       = var.config.os_type == "Windows" ? "allow-rdp" : "allow-ssh"
      priority                   = 100
      protocol                   = "Tcp"
      destination_port_range     = var.config.os_type == "Windows" ? "3389" : "22"
      source_address_prefixes    = var.config.allowed_cidrs
      destination_address_prefix = "*"
      source_port_range          = "*"
    }
  }
}

# https://registry.terraform.io/modules/Azure/avm-res-network-publicipaddress/azurerm
module "pip" {
  count = var.config.enable_public_ip ? 1 : 0

  source  = "Azure/avm-res-network-publicipaddress/azurerm"
  version = "~> 0.2"

  name                = "pip-${var.name}-${var.environment}"
  location            = var.location
  resource_group_name = local.rg_name
  enable_telemetry    = true
}

# https://registry.terraform.io/modules/Azure/avm-res-network-virtualnetwork/azurerm
module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.15"

  name             = "vnet-${var.name}-${var.environment}"
  location         = var.location
  parent_id        = local.rg_id
  address_space    = [var.config.vnet_address_space]
  enable_telemetry = true

  subnets = {
    snet_vms = {
      name             = "snet-vms"
      address_prefixes = [var.config.subnet_prefix]
      network_security_group = var.config.enable_public_ip ? {
        id = module.nsg[0].resource_id
      } : null
    }
  }
}

# https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine/azurerm
module "vm" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.15"

  name                = "${var.name}-${var.environment}"
  resource_group_name = local.rg_name
  location            = var.location
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
          public_ip_address_resource_id = var.config.enable_public_ip ? module.pip[0].resource_id : null
        }
      }
    }
  }

  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = var.config.os_disk_type
  }

  admin_username                  = var.config.admin_username
  generate_admin_password_or_key  = var.admin_password == null || var.config.disable_password_auth
  admin_password                  = var.config.disable_password_auth ? null : var.admin_password
  disable_password_authentication = var.config.disable_password_auth

  managed_identities = var.config.enable_system_identity ? { system_assigned = true } : null
  boot_diagnostics   = var.config.enable_boot_diagnostics ? {} : null

  tags = var.tags
}
