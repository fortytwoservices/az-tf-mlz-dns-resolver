variable "domain_name" {
  type        = string
  description = "The DNS namespace the rule forwards, dot-terminated: `contoso.com.`, or `.` for every name (a wildcard rule). One to 34 labels, or none for the wildcard. Changing it replaces the rule."
  nullable    = false

  validation {
    condition     = can(regex("^(\\.|([^.]+\\.){1,34})$", var.domain_name))
    error_message = "`domain_name` must end with a dot and have 1 to 34 labels (`contoso.com.`), or be `.` for every name."
  }
}

variable "enabled" {
  type        = bool
  default     = true
  description = "Whether the rule is applied. A disabled rule stays in the ruleset and is ignored."
  nullable    = false
}

variable "metadata" {
  type        = map(string)
  default     = {}
  description = "(Optional) Metadata on the rule, as string keys and values."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the forwarding rule: letters, digits, underscores and hyphens, starting with a letter. Changing it replaces the rule."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", var.name))
    error_message = "`name` must start with a letter and contain only letters, digits, underscores and hyphens."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the DNS forwarding ruleset that holds the rule."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/dnsForwardingRulesets", var.parent_id))
    error_message = "`parent_id` must be a DNS forwarding ruleset resource ID."
  }
}

variable "target_dns_servers" {
  type = list(object({
    ip_address = string
    port       = optional(number, 53)
  }))
  description = <<DESCRIPTION
The DNS servers queries in `domain_name` are forwarded to, 1 to 6, in order: the first one answers unless it stops responding. Not Azure DNS (`168.63.129.16`), which Azure refuses as a target.

- `ip_address` - IPv4 address of the DNS server.
- `port` - (Optional) Port of the DNS server. Defaults to `53`, the only port Azure accepts ("The target DNS server port must be 53").
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.target_dns_servers) >= 1 && length(var.target_dns_servers) <= 6
    error_message = "`target_dns_servers` must hold 1 to 6 DNS servers."
  }
  validation {
    condition = alltrue([
      for server in var.target_dns_servers :
      can(cidrnetmask("${server.ip_address}/32")) && server.ip_address != "168.63.129.16" # cidrhost would take IPv6 too
    ])
    error_message = "Each target DNS server needs an IPv4 address other than Azure DNS (`168.63.129.16`)."
  }
  validation {
    # The schema takes any port, but Azure refuses all but 53 (sandbox, 2026-10-28).
    condition     = alltrue([for server in var.target_dns_servers : server.port == 53])
    error_message = "Azure accepts only port 53 for target DNS servers."
  }
}
