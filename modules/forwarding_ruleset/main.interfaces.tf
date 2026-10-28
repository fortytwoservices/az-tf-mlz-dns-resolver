# A ruleset has no log categories; Azure offers AllMetrics only (sandbox, 2026-10-28), although Learn marks
# none of its metrics as exportable.
module "interfaces" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-interfaces.git?ref=v0.1.1"

  resource_id = azapi_resource.this.id
  location    = var.location
  # Role definitions are looked up by name in the resource group, which exists before the ruleset, so an
  # unknown role name fails during plan.
  role_assignment_definition_scope = var.parent_id
  lock                             = var.lock
  role_assignments                 = var.role_assignments
  diagnostic_settings              = var.diagnostic_settings
  # Azure applies the ruleset's lock to its rules and virtual network links too.
  lock_dependencies = merge(
    { for name, rule in module.forwarding_rule : "rule/${name}" => rule.lock_dependency },
    { for name, link in module.virtual_network_link : "link/${name}" => link.lock_dependency },
  )
  resource_types      = var.resource_types # its interface keys are read
  ignore_body_changes = var.ignore_body_changes
  retry               = var.retry
  timeouts            = var.timeouts
}
