resource "azapi_resource" "this" {
  type      = var.resource_types.network_dns_resolvers_outbound_endpoints
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  body = {
    properties = {
      subnet = { id = var.subnet_id }
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_dns_resolvers_outbound_endpoints) > 0 ? var.ignore_body_changes.network_dns_resolvers_outbound_endpoints : null
  # Azure cannot move an endpoint to another subnet (azurerm marks the subnet ForceNew). The input value is
  # compared, not the body path, so the casing Azure returns IDs in cannot trigger a replacement.
  replace_triggers_external_values = {
    subnet_id = var.subnet_id
  }
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
