module "forwarding_rule" {
  source   = "../forwarding_rule"
  for_each = var.forwarding_rules

  name                = each.key
  parent_id           = azapi_resource.this.id
  domain_name         = each.value.domain_name
  target_dns_servers  = each.value.target_dns_servers
  enabled             = each.value.enabled
  metadata            = each.value.metadata
  resource_types      = var.resource_types.network_dns_forwarding_rulesets_forwarding_rules
  ignore_body_changes = var.ignore_body_changes.network_dns_forwarding_rulesets_forwarding_rules
  retry               = var.retry
  timeouts            = var.timeouts
}

module "virtual_network_link" {
  source   = "../virtual_network_link"
  for_each = var.virtual_network_links

  name                = each.key
  parent_id           = azapi_resource.this.id
  virtual_network_id  = each.value.virtual_network_id
  metadata            = each.value.metadata
  resource_types      = var.resource_types.network_dns_forwarding_rulesets_virtual_network_links
  ignore_body_changes = var.ignore_body_changes.network_dns_forwarding_rulesets_virtual_network_links
  retry               = var.retry
  timeouts            = var.timeouts
}
