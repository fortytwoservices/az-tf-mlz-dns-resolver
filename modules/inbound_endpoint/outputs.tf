output "lock_dependency" {
  description = "Changes whenever the endpoint is created, replaced or changed. The caller passes it in the resolver's `lock_dependencies`: Azure applies the resolver's lock to the endpoint too, and a `ReadOnly` lock also blocks updating it in place, which keeps its ID."
  value       = sha256(jsonencode([azapi_resource.this.id, azapi_resource.this.body, azapi_resource.this.tags]))
}

output "name" {
  description = "Name of the inbound endpoint."
  value       = azapi_resource.this.name
}

output "private_ip_address" {
  description = "The endpoint's private IP address, static or assigned by Azure: the address on-premises DNS servers, a firewall's DNS proxy or a virtual network's DNS settings forward to."
  value       = azapi_resource.this.output.properties.ipConfigurations[0].privateIpAddress
}

output "resource_id" {
  description = "Resource ID of the inbound endpoint."
  value       = azapi_resource.this.id
}
