###############################################################################
# Outputs – add one block per VM following the example below.
###############################################################################

output "science_web_01_id" {
  description = "Resource ID of science-web-01."
  value       = module.science_web_01.resource_id
}

output "science_web_01_name" {
  description = "Name of science-web-01."
  value       = module.science_web_01.name
}

output "science_web_01_private_ip" {
  description = "Private IP address of science-web-01."
  value       = module.science_web_01.private_ip
}
