###############################################################################
# Outputs – Azure VM (AVM template)
###############################################################################

output "vm_id" {
  description = "Resource ID of the virtual machine."
  value       = module.virtual_machine.resource_id
}

output "vm_name" {
  description = "Name of the virtual machine."
  value       = module.virtual_machine.name
}

output "private_ip_address" {
  description = "Private IP address of the primary NIC."
  value       = module.virtual_machine.network_interfaces["nic0"].private_ip_address
}

output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.this.name
}
