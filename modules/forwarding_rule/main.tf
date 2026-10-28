resource "azapi_resource" "this" {
  type      = var.resource_types.network_dns_forwarding_rulesets_forwarding_rules
  name      = var.name
  parent_id = var.parent_id
  # Every property is sent, so that removing a value reaches Azure: azapi compares only the keys in the
  # body. Empty metadata is sent as null, which Azure returns for none: an empty map holds no keys, so
  # removing the last entry would never reach Azure (sandbox, 2026-10-28).
  body = {
    properties = {
      domainName          = var.domain_name
      forwardingRuleState = var.enabled ? "Enabled" : "Disabled"
      metadata            = length(var.metadata) > 0 ? var.metadata : null
      targetDnsServers    = [for server in var.target_dns_servers : { ipAddress = server.ip_address, port = server.port }]
    }
  }
  # Removing one metadata entry leaves the other keys unchanged, so azapi plans no change. A new version
  # sends the metadata again whenever the map changes, and the PUT replaces what Azure holds.
  sensitive_body         = { properties = { metadata = length(var.metadata) > 0 ? var.metadata : null } }
  sensitive_body_version = { "properties.metadata" = sha256(jsonencode(var.metadata)) }
  ignore_body_changes    = length(var.ignore_body_changes.network_dns_forwarding_rulesets_forwarding_rules) > 0 ? var.ignore_body_changes.network_dns_forwarding_rulesets_forwarding_rules : null
  # azurerm marks the domain name ForceNew. The input value is compared, not the body path, so the form
  # Azure returns the name in cannot trigger a replacement.
  replace_triggers_external_values = {
    domain_name = var.domain_name
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
