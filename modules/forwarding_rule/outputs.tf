output "lock_dependency" {
  description = "Changes whenever the rule is created, replaced or changed. The caller passes it in the ruleset's `lock_dependencies`: Azure applies the ruleset's lock to the rule too, and a `ReadOnly` lock also blocks updating it in place, which keeps its ID."
  value       = sha256(jsonencode([azapi_resource.this.id, azapi_resource.this.body]))
}

output "name" {
  description = "Name of the forwarding rule."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the forwarding rule."
  value       = azapi_resource.this.id
}
