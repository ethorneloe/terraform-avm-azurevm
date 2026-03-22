output "resource_id" {
  description = "Resource ID of the virtual machine."
  value       = module.vm.resource_id
}

output "name" {
  description = "Name of the virtual machine."
  value       = module.vm.name
}

output "private_ip" {
  description = "Private IP address of the virtual machine."
  value       = module.vm.network_interfaces["nic0"].private_ip_address
}

output "public_ip_address" {
  description = "Public IP address of the virtual machine. Null when enable_public_ip is false."
  value       = var.config.enable_public_ip ? module.pip[0].public_ip_address : null
}

output "resource_group_name" {
  description = "Name of the resource group containing the VM and its networking resources."
  value       = local.rg_name
}
