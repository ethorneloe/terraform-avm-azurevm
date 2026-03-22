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
