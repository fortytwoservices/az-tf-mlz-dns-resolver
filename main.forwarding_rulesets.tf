module "forwarding_ruleset" {
  source   = "./modules/forwarding_ruleset"
  for_each = var.forwarding_rulesets

  name                  = each.value.name
  parent_id             = var.parent_id
  location              = var.location
  outbound_endpoint_ids = [for endpoint in each.value.outbound_endpoints : try(module.outbound_endpoint[endpoint].resource_id, endpoint)]
  forwarding_rules      = each.value.rules
  virtual_network_links = each.value.virtual_network_links
  lock                  = each.value.lock
  role_assignments      = each.value.role_assignments
  diagnostic_settings   = each.value.diagnostic_settings
  tags                  = var.tags
  resource_types        = var.resource_types.network_dns_forwarding_rulesets
  ignore_body_changes   = var.ignore_body_changes.network_dns_forwarding_rulesets
  retry                 = var.retry
  timeouts              = var.timeouts
}
