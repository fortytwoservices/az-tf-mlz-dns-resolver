output "lock_dependency" {
  description = "Changes whenever the endpoint is created, replaced or changed. The caller passes it in the resolver's `lock_dependencies`: Azure applies the resolver's lock to the endpoint too, and a `ReadOnly` lock also blocks updating it in place, which keeps its ID."
  value       = sha256(jsonencode([azapi_resource.this.id, azapi_resource.this.body, azapi_resource.this.tags]))
}

output "name" {
  description = "Name of the outbound endpoint."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the outbound endpoint."
  value       = azapi_resource.this.id
}
