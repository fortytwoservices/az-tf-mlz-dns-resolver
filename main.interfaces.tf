# A resolver has no log categories; Azure offers AllMetrics only (sandbox, 2026-10-28), although Learn
# marks none of its metrics as exportable.
module "interfaces" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-interfaces.git?ref=v0.1.1"

  resource_id = azapi_resource.this.id
  location    = var.location
  # Role definitions are looked up by name in the resource group, which exists before the resolver, so
  # an unknown role name fails during plan.
  role_assignment_definition_scope = var.parent_id
  lock                             = var.lock
  role_assignments                 = var.role_assignments
  diagnostic_settings              = var.diagnostic_settings
  # Azure applies the resolver's lock to its endpoints too. Each endpoint's `lock_dependency` changes with
  # its body and tags, which a ReadOnly lock also blocks.
  lock_dependencies = merge(
    { for key, endpoint in module.inbound_endpoint : "inbound/${key}" => endpoint.lock_dependency },
    { for key, endpoint in module.outbound_endpoint : "outbound/${key}" => endpoint.lock_dependency },
  )
  resource_types      = var.resource_types # its interface keys are read
  ignore_body_changes = var.ignore_body_changes
  retry               = var.retry
  timeouts            = var.timeouts
}
