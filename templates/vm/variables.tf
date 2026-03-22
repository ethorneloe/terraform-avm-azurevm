###############################################################################
# Variables – Azure VM (AVM template)
###############################################################################

# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where resources will be deployed."
}

variable "location" {
  type        = string
  description = "Azure region for all resources, e.g. \"uksouth\"."
  default     = "uksouth"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "create_vnet" {
  type        = bool
  description = "Set to true to create a new VNet/Subnet. Set to false and supply existing_subnet_id to use an existing subnet."
  default     = true
}

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network (only used when create_vnet = true)."
  default     = "vnet-main"
}

variable "vnet_address_space" {
  type        = string
  description = "CIDR block for the virtual network (only used when create_vnet = true)."
  default     = "10.0.0.0/16"
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet (only used when create_vnet = true)."
  default     = "snet-vms"
}

variable "subnet_address_prefix" {
  type        = string
  description = "CIDR block for the subnet (only used when create_vnet = true)."
  default     = "10.0.1.0/24"
}

variable "existing_subnet_id" {
  type        = string
  description = "Full resource ID of an existing subnet (only used when create_vnet = false)."
  default     = null
}

# ---------------------------------------------------------------------------
# Virtual Machine
# ---------------------------------------------------------------------------

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine."
}

variable "os_type" {
  type        = string
  description = "Operating system type: \"Linux\" or \"Windows\"."
  default     = "Linux"

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be \"Linux\" or \"Windows\"."
  }
}

variable "vm_size" {
  type        = string
  description = "Azure VM SKU size, e.g. \"Standard_B2s\"."
  default     = "Standard_B2s"
}

# OS image
variable "image_publisher" {
  type        = string
  description = "Image publisher, e.g. \"Canonical\" or \"MicrosoftWindowsServer\"."
  default     = "Canonical"
}

variable "image_offer" {
  type        = string
  description = "Image offer, e.g. \"0001-com-ubuntu-server-jammy\" or \"WindowsServer\"."
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  type        = string
  description = "Image SKU, e.g. \"22_04-lts-gen2\" or \"2022-Datacenter\"."
  default     = "22_04-lts-gen2"
}

# OS disk
variable "os_disk_type" {
  type        = string
  description = "OS disk storage type: \"Standard_LRS\", \"StandardSSD_LRS\", or \"Premium_LRS\"."
  default     = "StandardSSD_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.os_disk_type)
    error_message = "os_disk_type must be one of: Standard_LRS, StandardSSD_LRS, Premium_LRS."
  }
}

# Admin credentials
variable "admin_username" {
  type        = string
  description = "Administrator username for the VM."
  default     = "azureadmin"
}

variable "generate_admin_credentials" {
  type        = bool
  description = "When true the AVM module auto-generates and stores credentials in a Key Vault. Set to false to supply admin_password manually (not recommended for production)."
  default     = true
}

variable "admin_password" {
  type        = string
  description = "Admin password (only used when generate_admin_credentials = false). Store in Key Vault, not in tfvars."
  default     = null
  sensitive   = true
}

variable "disable_password_auth" {
  type        = bool
  description = "Linux only – disable password authentication in favour of SSH keys."
  default     = true
}

# ---------------------------------------------------------------------------
# Optional features
# ---------------------------------------------------------------------------

variable "enable_system_identity" {
  type        = bool
  description = "Assign a system-assigned managed identity to the VM."
  default     = false
}

variable "enable_boot_diagnostics" {
  type        = bool
  description = "Enable boot diagnostics (uses a managed storage account)."
  default     = true
}

variable "enable_telemetry" {
  type        = bool
  description = "Enable AVM telemetry. Set to false to opt out."
  default     = true
}
