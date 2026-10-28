resource "azapi_resource" "this" {
  type      = var.resource_types.network_dns_forwarding_rulesets
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  # Forwarding rules and virtual network links are child resources; ARM keeps them when the ruleset is
  # written without them.
  body = {
    properties = {
      dnsResolverOutboundEndpoints = [for id in var.outbound_endpoint_ids : { id = id }]
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.network_dns_forwarding_rulesets) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
