###############################################################################
# science-web-01
#
# Research & Science web VM — data analysis, lab tooling, research compute.
# Copy this file and rename it to add another VM for the Science team.
# All values specific to this VM are defined in the locals block below.
###############################################################################

locals {
  science_web_01 = {
    vnet_address_space      = "10.1.0.0/16"
    subnet_prefix           = "10.1.1.0/24"
    vm_size                 = "Standard_D4s_v3" # memory-optimised for data workloads
    os_type                 = "Linux"
    image = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
    }
    os_disk_type            = "Premium_LRS"
    admin_username          = "azureadmin"
    disable_password_auth   = true
    enable_system_identity  = true  # allows access to Key Vault, Storage, etc.
    enable_boot_diagnostics = true
    zone                    = "1"   # pin to zone 1 for data-locality
    enable_public_ip        = false
    allowed_cidrs           = []    # set to specific CIDRs (e.g. ["203.0.113.10/32"]) to enable SSH access
  }
}

module "science_web_01" {
  source = "../../../../modules/vm"

  name                = "science-web-01"
  environment         = var.environment
  location            = "eastus"
  resource_group_name = "rg-science-vms"
  tags                = merge(var.tags, { team = "science", cost-center = "research" })
  config              = local.science_web_01
  admin_password      = var.admin_password
}
