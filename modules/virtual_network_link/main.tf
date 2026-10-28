resource "azapi_resource" "this" {
  type      = var.resource_types.network_dns_forwarding_rulesets_virtual_network_links
  name      = var.name
  parent_id = var.parent_id
  # Empty metadata is sent as null, which Azure returns for none: azapi compares only the keys in the body,
  # and an empty map holds none, so removing the last entry would never reach Azure (sandbox, 2026-10-28).
  body = {
    properties = {
      metadata       = length(var.metadata) > 0 ? var.metadata : null
      virtualNetwork = { id = var.virtual_network_id }
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links : null
  # Azure cannot point a link at another virtual network (Learn: "cannot be changed after creation"). The
  # input value is compared, not the body path, so the casing Azure returns IDs in cannot trigger a
  # replacement.
  replace_triggers_external_values = {
    virtual_network_id = var.virtual_network_id
  }
  response_export_values = []
  retry                  = var.retry

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
