###############################################################################
# Outputs – add one block per VM following the example below.
###############################################################################

output "bizapps_web_01_id" {
  description = "Resource ID of bizapps-web-01."
  value       = module.bizapps_web_01.resource_id
}

output "bizapps_web_01_name" {
  description = "Name of bizapps-web-01."
  value       = module.bizapps_web_01.name
}

output "bizapps_web_01_private_ip" {
  description = "Private IP address of bizapps-web-01."
  value       = module.bizapps_web_01.private_ip
}
