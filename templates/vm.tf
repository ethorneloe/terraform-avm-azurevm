###############################################################################
# <vm-name>.tf  –  Template for adding a new VM.
#
# Steps:
#   1. Copy this file to infrastructure/<bu>/virtual-machines/<vm-name>.tf
#   2. Replace every occurrence of <vm-name> / <vm_name>:
#      <vm-name>  → kebab-case  (e.g. web-server)   used in Azure resource names
#      <vm_name>  → snake_case  (e.g. web_server)   used in HCL identifiers
#   3. Adjust the locals block – size, image, CIDRs, etc.
#   4. Add three output blocks to outputs.tf (shown at the bottom of this file)
###############################################################################

locals {
  <vm_name> = {
    vnet_address_space      = "10.x.0.0/16" # choose a non-overlapping CIDR
    subnet_prefix           = "10.x.1.0/24"
    vm_size                 = "Standard_B2s"
    os_type                 = "Linux" # or "Windows"
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
    allowed_cidrs           = ["*"] # restrict to known IPs in production
  }
}

module "<vm_name>" {
  source = "../../../../modules/vm"

  name           = "<vm-name>"
  environment    = var.environment
  location       = var.location
  tags           = var.tags
  config         = local.<vm_name>
  admin_password = var.admin_password
  # resource_group_name = "rg-shared"  # omit to auto-create rg-<name>-<env>
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
#   value       = module.<vm_name>.private_ip
# }
