variable "metadata" {
  type        = map(string)
  default     = {}
  description = "(Optional) Metadata on the link, as string keys and values."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the virtual network link. Changing it replaces the link."
  nullable    = false
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the DNS forwarding ruleset that holds the link."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/dnsForwardingRulesets", var.parent_id))
    error_message = "`parent_id` must be a DNS forwarding ruleset resource ID."
  }
}

variable "virtual_network_id" {
  type        = string
  description = "Resource ID of the virtual network whose DNS queries the ruleset's rules apply to, in the ruleset's region and tenant (any subscription). Do not link the virtual network of an inbound endpoint that a rule in the ruleset forwards to: its queries would loop. Changing it replaces the link."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.virtual_network_id))
    error_message = "`virtual_network_id` must be a virtual network resource ID."
  }
}
