variable "ignore_body_changes" {
  type = object({
    network_dns_resolvers_inbound_endpoints = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Paths in the inbound endpoint's `body` whose changes the AzAPI provider ignores. Paths use dot notation, for example `properties.ipConfigurations`. Configuration changes at an ignored path are **not** sent to Azure until that path is removed from the list.

- `network_dns_resolvers_inbound_endpoints` - Ignored body paths for the inbound endpoint.
DESCRIPTION
  nullable    = false
}

variable "resource_types" {
  type = object({
    network_dns_resolvers_inbound_endpoints = optional(string, "Microsoft.Network/dnsResolvers/inboundEndpoints@2025-05-01")
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` string used by this module.

- `network_dns_resolvers_inbound_endpoints` - The inbound endpoint.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration for the `azapi` resource in this module. Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.
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
Per-operation timeouts for the `azapi` resource in this module. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
