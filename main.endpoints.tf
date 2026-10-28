module "inbound_endpoint" {
  source   = "./modules/inbound_endpoint"
  for_each = var.inbound_endpoints

  name                = each.value.name
  parent_id           = azapi_resource.this.id
  location            = var.location
  subnet_id           = each.value.subnet_id
  private_ip_address  = each.value.private_ip_address
  tags                = var.tags
  resource_types      = var.resource_types.network_dns_resolvers_inbound_endpoints
  ignore_body_changes = var.ignore_body_changes.network_dns_resolvers_inbound_endpoints
  retry               = var.retry
  timeouts            = var.timeouts
}

module "outbound_endpoint" {
  source   = "./modules/outbound_endpoint"
  for_each = var.outbound_endpoints

  name                = each.value.name
  parent_id           = azapi_resource.this.id
  location            = var.location
  subnet_id           = each.value.subnet_id
  tags                = var.tags
  resource_types      = var.resource_types.network_dns_resolvers_outbound_endpoints
  ignore_body_changes = var.ignore_body_changes.network_dns_resolvers_outbound_endpoints
  retry               = var.retry
  timeouts            = var.timeouts
}
