###############################################################################
# Outputs – add one block per VM following the example below.
###############################################################################

output "example_vm_id" {
  description = "Resource ID of example-vm."
  value       = module.example_vm.resource_id
}

output "example_vm_name" {
  description = "Name of example-vm."
  value       = module.example_vm.name
}

output "example_vm_private_ip" {
  description = "Private IP address of example-vm."
  value       = module.example_vm.network_interfaces["nic0"].private_ip_address
}
