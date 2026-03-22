###############################################################################
# bizapps-vm
#
# Business Applications team VM — ERP, CRM, and internal tooling workloads.
# Copy this file and rename it to add another VM for the BizApps team.
# All values specific to this VM are defined in the locals block below.
###############################################################################

locals {
  bizapps_vm = {
    vnet_address_space      = "10.2.0.0/16"
    subnet_prefix           = "10.2.1.0/24"
    vm_size                 = "Standard_B4ms"   # burstable — steady-state business apps
    os_type                 = "Windows"
    image = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
    }
    os_disk_type            = "StandardSSD_LRS"
    admin_username          = "azureadmin"
    disable_password_auth   = false # Windows requires password auth
    enable_system_identity  = false
    enable_boot_diagnostics = true
    zone                    = null  # "1", "2", or "3" for zonal deployments
    enable_public_ip        = false
    allowed_cidrs           = []    # set to specific CIDRs (e.g. ["203.0.113.10/32"]) to enable RDP access
  }
}

module "bizapps_vm" {
  source = "../../../../modules/vm"

  name                = "bizapps-vm"
  environment         = var.environment
  location            = "westeurope"
  resource_group_name = "rg-bizapps-vms"
  tags                = merge(var.tags, { team = "bizapps", cost-center = "operations" })
  config              = local.bizapps_vm
  admin_password      = var.admin_password
}
