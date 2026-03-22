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

variable "config" {
  description = "VM-specific configuration."
  type = object({
    vnet_address_space      = string
    subnet_prefix           = string
    vm_size                 = string
    os_type                 = string
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
  })
}
