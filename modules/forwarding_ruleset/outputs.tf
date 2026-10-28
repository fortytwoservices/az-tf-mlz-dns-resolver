output "diagnostic_setting_resource_ids" {
  description = "Resource IDs of the diagnostic settings on the ruleset, by key."
  value       = module.interfaces.diagnostic_setting_resource_ids
}

output "forwarding_rule_resource_ids" {
  description = "Resource IDs of the forwarding rules, by rule name."
  value       = { for name, rule in module.forwarding_rule : name => rule.resource_id }
}

output "lock_resource_id" {
  description = "Resource ID of the ruleset's lock; null without one."
  value       = module.interfaces.lock_resource_id
}

output "name" {
  description = "Name of the DNS forwarding ruleset."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the DNS forwarding ruleset."
  value       = azapi_resource.this.id
}

output "role_assignment_resource_ids" {
  description = "Resource IDs of the role assignments on the ruleset, by key."
  value       = module.interfaces.role_assignment_resource_ids
}

output "virtual_network_link_resource_ids" {
  description = "Resource IDs of the virtual network links, by link name."
  value       = { for name, link in module.virtual_network_link : name => link.resource_id }
}
