variable "ignore_body_changes" {
  type = object({
    network_dns_resolvers          = optional(list(string), [])
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    insights_diagnostic_settings   = optional(list(string), [])

    network_dns_resolvers_inbound_endpoints = optional(object({
      network_dns_resolvers_inbound_endpoints = optional(list(string), [])
    }), {})
    network_dns_resolvers_outbound_endpoints = optional(object({
      network_dns_resolvers_outbound_endpoints = optional(list(string), [])
    }), {})
    network_dns_forwarding_rulesets = optional(object({
      network_dns_forwarding_rulesets = optional(list(string), [])
      authorization_locks             = optional(list(string), [])
      authorization_role_assignments  = optional(list(string), [])
      insights_diagnostic_settings    = optional(list(string), [])
      network_dns_forwarding_rulesets_forwarding_rules = optional(object({
        network_dns_forwarding_rulesets_forwarding_rules = optional(list(string), [])
      }), {})
      network_dns_forwarding_rulesets_virtual_network_links = optional(object({
        network_dns_forwarding_rulesets_virtual_network_links = optional(list(string), [])
      }), {})
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Paths in each resource's `body` whose changes the AzAPI provider ignores. Prefer Terraform's `lifecycle.ignore_changes` when the paths are static; use this variable when the paths must be derived from variables or other non-static values.

Paths use dot notation, for example `properties.metadata`. Individual list items cannot be targeted; ignore the whole list property instead. Configuration changes at an ignored path are **not** sent to Azure until that path is removed from the list. Changes take effect only after an apply, because the value is held in provider-private state.

- `network_dns_resolvers` - Ignored body paths for the resolver.
- `authorization_locks` - Ignored body paths for the resolver's lock.
- `authorization_role_assignments` - Ignored body paths for the resolver's role assignments.
- `insights_diagnostic_settings` - Ignored body paths for the resolver's diagnostic settings.
- `network_dns_resolvers_inbound_endpoints` - Slot for `modules/inbound_endpoint`.
- `network_dns_resolvers_outbound_endpoints` - Slot for `modules/outbound_endpoint`.
- `network_dns_forwarding_rulesets` - Slot for `modules/forwarding_ruleset` (its `network_dns_forwarding_rulesets`, `authorization_locks`, `authorization_role_assignments`, `insights_diagnostic_settings`, and its slots for `modules/forwarding_rule` and `modules/virtual_network_link`).
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_dns_resolvers          = optional(string, "Microsoft.Network/dnsResolvers@2025-05-01")
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    insights_diagnostic_settings   = optional(string, "Microsoft.Insights/diagnosticSettings@2021-05-01-preview")

    network_dns_resolvers_inbound_endpoints = optional(object({
      network_dns_resolvers_inbound_endpoints = optional(string)
    }), {})
    network_dns_resolvers_outbound_endpoints = optional(object({
      network_dns_resolvers_outbound_endpoints = optional(string)
    }), {})
    network_dns_forwarding_rulesets = optional(object({
      network_dns_forwarding_rulesets = optional(string)
      authorization_locks             = optional(string)
      authorization_role_assignments  = optional(string)
      insights_diagnostic_settings    = optional(string)
      network_dns_forwarding_rulesets_forwarding_rules = optional(object({
        network_dns_forwarding_rulesets_forwarding_rules = optional(string)
      }), {})
      network_dns_forwarding_rulesets_virtual_network_links = optional(object({
        network_dns_forwarding_rulesets_virtual_network_links = optional(string)
      }), {})
    }), {})
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module and its submodules. Each key defaults to a tested value; supply only the keys you want to override.

- `network_dns_resolvers` - The resolver.
- `authorization_locks` - The lock on the resolver.
- `authorization_role_assignments` - Role assignments on the resolver.
- `insights_diagnostic_settings` - Diagnostic settings on the resolver.
- `network_dns_resolvers_inbound_endpoints` - Slot for `modules/inbound_endpoint`. Defaults live in the submodule.
- `network_dns_resolvers_outbound_endpoints` - Slot for `modules/outbound_endpoint`. Defaults live in the submodule.
- `network_dns_forwarding_rulesets` - Slot for `modules/forwarding_ruleset`, with its slots for `modules/forwarding_rule` and `modules/virtual_network_link`. Defaults live in the submodules.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string), ["AnotherOperationInProgress", "CannotDeleteResource"])
    interval_seconds     = optional(number, 30)
    max_interval_seconds = optional(number, 300)
  })
  default     = {}
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module and its submodules. Defaults retry `AnotherOperationInProgress`, which Azure returns while another write to the resolver or its virtual network runs, and `CannotDeleteResource`, which Azure returns for a resolver whose endpoints it has just reported deleted but still counts as nested resources; any field can be overridden.

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry. Defaults to `["AnotherOperationInProgress", "CannotDeleteResource"]`.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds. Defaults to `30`.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds. Defaults to `300`.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every `azapi` resource managed by the module and its submodules. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
