###############################################################################
# Shared variables – apply to all VMs in this root module.
# VM-specific settings (size, image, CIDRs, etc.) are defined as locals in
# each <vm-name>.tf file and passed to the shared modules/vm child module.
###############################################################################

variable "location" {
  type        = string
  description = "Azure region for all resources, e.g. \"uksouth\"."
  default     = "uksouth"
}

variable "environment" {
  type        = string
  description = "Deployment environment: dev, test, or prod."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources."
  default     = {}
}
