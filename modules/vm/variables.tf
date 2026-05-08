variable "name" {
  type        = string
  description = "VM name (kebab-case). Used to construct all Azure resource names."
}

variable "environment" {
  type        = string
  description = "Deployment environment: dev, test, or prod."
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

variable "resource_group_name" {
  type        = string
  description = "Name of an existing resource group to use. When null, a new resource group named rg-<name>-<env> is created."
  default     = null
}

variable "config" {
  description = "VM-specific configuration."
  type = object({
    vnet_address_space = string
    subnet_prefix      = string
    vm_size            = string
    os_type            = string
    image = object({
      publisher = string
      offer     = string
      sku       = string
    })
    os_disk_type            = string
    admin_username          = string
    disable_password_auth   = bool
    enable_system_identity  = bool
    enable_boot_diagnostics = bool
    zone                    = optional(string)
    enable_public_ip        = optional(bool, false)
    allowed_cidrs           = optional(list(string), [])
  })
}

variable "admin_password" {
  type        = string
  description = "Admin password for the VM. When provided and password auth is enabled, disables auto-generation. Ignored when disable_password_auth is true (SSH key auth is used instead)."
  sensitive   = true
  default     = null
}
