output "inbound_endpoint_ip_addresses" {
  description = "Private IP addresses of the inbound endpoints, by key."
  value       = module.dns_resolver.inbound_endpoint_ip_addresses
}

output "resource_id" {
  description = "Resource ID of the DNS private resolver."
  value       = module.dns_resolver.resource_id
}
