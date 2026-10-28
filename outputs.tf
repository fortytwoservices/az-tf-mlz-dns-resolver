output "forwarding_rule_resource_ids" {
  description = "Resource IDs of the forwarding rules, by ruleset key, then rule name."
  value       = { for key, ruleset in module.forwarding_ruleset : key => ruleset.forwarding_rule_resource_ids }
}

output "forwarding_ruleset_resource_ids" {
  description = "Resource IDs of the DNS forwarding rulesets, by key."
  value       = { for key, ruleset in module.forwarding_ruleset : key => ruleset.resource_id }
}

output "inbound_endpoint_ip_addresses" {
  description = "Private IP addresses of the inbound endpoints, by key: the DNS servers to forward to from on-premises, a firewall's DNS proxy or a virtual network's DNS settings."
  value       = { for key, endpoint in module.inbound_endpoint : key => endpoint.private_ip_address }
}

output "inbound_endpoint_resource_ids" {
  description = "Resource IDs of the inbound endpoints, by key."
  value       = { for key, endpoint in module.inbound_endpoint : key => endpoint.resource_id }
}

output "name" {
  description = "Name of the DNS private resolver."
  value       = azapi_resource.this.name
}

output "outbound_endpoint_resource_ids" {
  description = "Resource IDs of the outbound endpoints, by key."
  value       = { for key, endpoint in module.outbound_endpoint : key => endpoint.resource_id }
}

output "resource_id" {
  description = "Resource ID of the DNS private resolver."
  value       = azapi_resource.this.id
}

output "virtual_network_link_resource_ids" {
  description = "Resource IDs of the rulesets' virtual network links, by ruleset key, then link name."
  value       = { for key, ruleset in module.forwarding_ruleset : key => ruleset.virtual_network_link_resource_ids }
}
