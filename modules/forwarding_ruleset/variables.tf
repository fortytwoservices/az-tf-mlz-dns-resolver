variable "location" {
  type        = string
  description = "Azure region of the ruleset: the region of its outbound endpoints. It serves virtual networks in this region only."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the DNS forwarding ruleset. Changing it replaces the ruleset, and with it its rules and links."
  nullable    = false
}

variable "outbound_endpoint_ids" {
  type        = list(string)
  description = "Resource IDs of the outbound endpoints that send the ruleset's queries to their target DNS servers: one or two, of the same DNS private resolver. An outbound endpoint serves at most two rulesets."
  nullable    = false

  validation {
    condition     = length(var.outbound_endpoint_ids) >= 1 && length(var.outbound_endpoint_ids) <= 2 && length(distinct([for id in var.outbound_endpoint_ids : lower(id)])) == length(var.outbound_endpoint_ids)
    error_message = "`outbound_endpoint_ids` must hold one or two different outbound endpoints."
  }
  validation {
    condition     = alltrue([for id in var.outbound_endpoint_ids : can(provider::azapi::parse_resource_id("Microsoft.Network/dnsResolvers/outboundEndpoints", id))])
    error_message = "Each of `outbound_endpoint_ids` must be a DNS private resolver outbound endpoint resource ID."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group that holds the ruleset."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "forwarding_rules" {
  type = map(object({
    domain_name = string
    target_dns_servers = list(object({
      ip_address = string
      port       = optional(number, 53)
    }))
    enabled  = optional(bool, true)
    metadata = optional(map(string), {})
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Forwarding rules, by rule name (letters, digits, underscores and hyphens, starting with a letter), each through `modules/forwarding_rule`; at most 1,000. A query from a linked virtual network that matches a rule goes to the rule's DNS servers; the longest matching domain wins, and other queries go to Azure DNS.

- `domain_name` - The DNS namespace forwarded, dot-terminated (`contoso.com.`), or `.` for every name. Changing it replaces the rule.
- `target_dns_servers` - 1 to 6 DNS servers, `ip_address` and `port` (defaults to `53`), tried in order. Not Azure DNS (`168.63.129.16`).
- `enabled` - (Optional) Whether the rule applies. Defaults to `true`.
- `metadata` - (Optional) Metadata on the rule.
DESCRIPTION

  validation {
    condition     = length(var.forwarding_rules) <= 1000
    error_message = "A ruleset holds at most 1,000 forwarding rules."
  }
}

variable "virtual_network_links" {
  type = map(object({
    virtual_network_id = string
    metadata           = optional(map(string), {})
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Virtual networks whose DNS queries the rules apply to, by link name, each through `modules/virtual_network_link`; at most 500. Do not link the virtual network of an inbound endpoint that a rule forwards to: its queries would loop.

- `virtual_network_id` - Resource ID of the virtual network, in the ruleset's region and any subscription of the tenant. Changing it replaces the link.
- `metadata` - (Optional) Metadata on the link.
DESCRIPTION

  validation {
    condition     = length(var.virtual_network_links) <= 500
    error_message = "A ruleset holds at most 500 virtual network links."
  }
}
