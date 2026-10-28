resource "azapi_resource" "this" {
  type      = var.resource_types.network_dns_resolvers_inbound_endpoints
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  body = {
    properties = {
      ipConfigurations = [merge(
        {
          subnet                    = { id = var.subnet_id }
          privateIpAllocationMethod = var.private_ip_address == null ? "Dynamic" : "Static"
        },
        # A dynamic address is left out of the body: Azure picks it, and azapi compares only the keys in
        # the body, so the address it picked is not a change.
        var.private_ip_address == null ? null : { privateIpAddress = var.private_ip_address },
      )]
    }
  }
  ignore_body_changes = length(var.ignore_body_changes.network_dns_resolvers_inbound_endpoints) > 0 ? var.ignore_body_changes.network_dns_resolvers_inbound_endpoints : null
  # Azure cannot change an endpoint's IP configuration (azurerm marks all of it ForceNew). The input values
  # are compared, not body paths, so the casing Azure returns IDs in cannot trigger a replacement.
  replace_triggers_external_values = {
    private_ip_address = var.private_ip_address
    subnet_id          = var.subnet_id
  }
  response_export_values = ["properties.ipConfigurations"]
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
