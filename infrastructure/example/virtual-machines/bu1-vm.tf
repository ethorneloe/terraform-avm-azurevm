###############################################################################
# bu1-vm
#
# Business Unit 1 VM. Copy this file and rename it to add another VM for BU1.
# All values specific to this VM are defined in the locals block below.
###############################################################################

locals {
  bu1_vm = {
    vnet_address_space      = "10.1.0.0/16"
    subnet_prefix           = "10.1.1.0/24"
    vm_size                 = "Standard_B2s"
    os_type                 = "Linux"
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
    zone                    = null  # "1", "2", or "3" for zonal deployments
    enable_public_ip        = false # set to true to attach a public IP and open SSH/RDP
    allowed_cidrs           = []    # set to specific CIDRs (e.g. ["203.0.113.10/32"]) to enable SSH/RDP access
  }
}

module "bu1_vm" {
  source = "../../../../modules/vm"

  name                = "bu1-vm"
  environment         = var.environment
  location            = "eastus"
  resource_group_name = "rg-bu1-vms"
  tags                = var.tags
  config              = local.bu1_vm
  admin_password      = var.admin_password
}
