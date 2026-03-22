###############################################################################
# Azure Verified Module – Virtual Machine: example-vm
#
# This is the example/reference configuration. See templates/vm/ for the
# blank template to copy when adding a new VM.
#
# Terraform and provider configuration lives in providers.tf.
# Backend configuration is supplied per-environment via env/<env>/<env>.tfbackend.
# Variable values are supplied per-environment via env/<env>/<env>.tfvars.
###############################################################################
# Resource Group
###############################################################################

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

###############################################################################
# Virtual Network & Subnet  (skip if using an existing vnet – see variables.tf)
###############################################################################

resource "azurerm_virtual_network" "this" {
  count               = var.create_vnet ? 1 : 0
  name                = var.vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  count                = var.create_vnet ? 1 : 0
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this[0].name
  address_prefixes     = [var.subnet_address_prefix]
}

locals {
  subnet_id = var.create_vnet ? azurerm_subnet.this[0].id : var.existing_subnet_id
}

###############################################################################
# Azure Verified Module – Compute: Virtual Machine
# https://registry.terraform.io/modules/Azure/avm-res-compute-virtualmachine
###############################################################################

module "virtual_machine" {
  source  = "Azure/avm-res-compute-virtualmachine/azurerm"
  version = "~> 0.15"

  # Identity & location
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  name                = var.vm_name

  # OS type  ("Linux" or "Windows")
  os_type  = var.os_type
  sku_size = var.vm_size

  # OS image
  source_image_reference = {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = "latest"
  }

  # Networking – one NIC on the selected subnet
  network_interfaces = {
    nic0 = {
      name = "${var.vm_name}-nic"
      ip_configurations = {
        ipconfig0 = {
          name                          = "ipconfig0"
          subnet_id                     = local.subnet_id
          private_ip_address_allocation = "Dynamic"
        }
      }
    }
  }

  # OS disk
  os_disk = {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
  }

  # Admin credentials
  admin_username                  = var.admin_username
  generate_admin_password_or_key  = var.generate_admin_credentials
  admin_password                  = var.generate_admin_credentials ? null : var.admin_password
  disable_password_authentication = var.os_type == "Linux" ? var.disable_password_auth : false

  # Managed identity (optional – set to null to disable)
  managed_identities = var.enable_system_identity ? {
    system_assigned = true
  } : null

  # Boot diagnostics (uses managed storage account by default)
  boot_diagnostics = var.enable_boot_diagnostics ? {} : null

  tags = var.tags

  enable_telemetry = var.enable_telemetry
}
