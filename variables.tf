variable "location" {
  type        = string
  description = "Azure region of the DNS private resolver, and of the endpoints and rulesets the module creates: the region of `virtual_network_id`."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the DNS private resolver. Changing it replaces the resolver."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9_-]{0,78}[a-zA-Z0-9])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, underscores and hyphens, starting and ending with a letter or digit."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group that holds the resolver and the rulesets."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "virtual_network_id" {
  type        = string
  description = "Resource ID of the resolver's virtual network, in the resolver's region; one resolver per virtual network. The endpoints' subnets are in it. Changing it replaces the resolver and its endpoints."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks", var.virtual_network_id))
    error_message = "`virtual_network_id` must be a virtual network resource ID."
  }
}

variable "inbound_endpoints" {
  type = map(object({
    name               = string
    subnet_id          = string
    private_ip_address = optional(string)
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Inbound endpoints, by key: the IP addresses that on-premises DNS servers, a firewall's DNS proxy or a virtual network's DNS settings send queries to, answered by Azure DNS with the private DNS zones linked to the resolver's virtual network. At most 5.

- `name` - Name of the endpoint.
- `subnet_id` - Resource ID of its subnet in `virtual_network_id`: /28 to /24, delegated to `Microsoft.Network/dnsResolvers`, used by no other endpoint or service.
- `private_ip_address` - (Optional) A static IPv4 address in the subnet. When null Azure assigns the subnet's fifth address (`.4` in `10.0.0.0/28`). Set it when the address must be known before apply, for example `cidrhost(<subnet prefix>, 4)`.

Changing an endpoint's subnet or address replaces it.
DESCRIPTION

  validation {
    condition     = length(var.inbound_endpoints) <= 5
    error_message = "A DNS private resolver has at most 5 inbound endpoints."
  }
  validation {
    condition = alltrue([
      for endpoint in var.inbound_endpoints :
      can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", endpoint.subnet_id)) && startswith(lower(endpoint.subnet_id), "${lower(var.virtual_network_id)}/subnets/")
    ])
    error_message = "Each inbound endpoint's `subnet_id` must be a subnet of `virtual_network_id`."
  }
}

variable "outbound_endpoints" {
  type = map(object({
    name      = string
    subnet_id = string
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
Outbound endpoints, by key: where queries matching a forwarding ruleset's rules leave the virtual network for their target DNS servers. At most 5.

- `name` - Name of the endpoint.
- `subnet_id` - Resource ID of its subnet in `virtual_network_id`: /28 to /24, delegated to `Microsoft.Network/dnsResolvers`, used by no other endpoint or service. Changing it replaces the endpoint.

Azure deletes an outbound endpoint only once no ruleset uses it, and Terraform deletes a removed endpoint before it updates the rulesets that used it. So remove an endpoint from every ruleset's `outbound_endpoints` in one apply, and from this map in the next; removing a ruleset together with its endpoints works in one apply.
DESCRIPTION

  validation {
    condition     = length(var.outbound_endpoints) <= 5
    error_message = "A DNS private resolver has at most 5 outbound endpoints."
  }
  validation {
    condition = alltrue([
      for endpoint in var.outbound_endpoints :
      can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", endpoint.subnet_id)) && startswith(lower(endpoint.subnet_id), "${lower(var.virtual_network_id)}/subnets/")
    ])
    error_message = "Each outbound endpoint's `subnet_id` must be a subnet of `virtual_network_id`."
  }
  validation {
    condition     = length(distinct([for endpoint in concat(values(var.inbound_endpoints), values(var.outbound_endpoints)) : lower(endpoint.subnet_id)])) == length(var.inbound_endpoints) + length(var.outbound_endpoints)
    error_message = "Each endpoint, inbound or outbound, needs a subnet of its own."
  }
}

variable "forwarding_rulesets" {
  type = map(object({
    name               = string
    outbound_endpoints = list(string)
    rules = optional(map(object({
      domain_name = string
      target_dns_servers = list(object({
        ip_address = string
        port       = optional(number, 53)
      }))
      enabled  = optional(bool, true)
      metadata = optional(map(string), {})
    })), {})
    virtual_network_links = optional(map(object({
      virtual_network_id = string
      metadata           = optional(map(string), {})
    })), {})
    lock = optional(object({
      kind  = string
      name  = optional(string, null)
      notes = optional(string, null)
    }))
    role_assignments = optional(map(object({
      name                                   = optional(string, null)
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
    diagnostic_settings = optional(map(object({
      name = optional(string, null)
      logs = optional(set(object({
        category       = optional(string, null)
        category_group = optional(string, null)
        enabled        = optional(bool, true)
        retention_policy = optional(object({
          days    = optional(number, 0)
          enabled = optional(bool, false)
        }), {})
      })), [])
      metrics = optional(set(object({
        category = optional(string, null)
        enabled  = optional(bool, true)
        retention_policy = optional(object({
          days    = optional(number, 0)
          enabled = optional(bool, false)
        }), {})
      })), [])
      log_analytics_destination_type           = optional(string, "Dedicated")
      workspace_resource_id                    = optional(string, null)
      storage_account_resource_id              = optional(string, null)
      event_hub_authorization_rule_resource_id = optional(string, null)
      event_hub_name                           = optional(string, null)
      marketplace_partner_resource_id          = optional(string, null)
    })), {})
  }))
  default     = {}
  nullable    = false
  description = <<DESCRIPTION
DNS forwarding rulesets the module creates in `parent_id`, by key, each through `modules/forwarding_ruleset` with its rules and virtual network links. A virtual network linked to a ruleset sends queries that match a rule to the rule's DNS servers, through the ruleset's outbound endpoints; other queries go to Azure DNS. The longest matching domain wins.

- `name` - Name of the ruleset. Changing it replaces the ruleset, its rules and its links.
- `outbound_endpoints` - One or two outbound endpoints of the resolver: keys of `outbound_endpoints`, or resource IDs.
- `rules` - (Optional) Forwarding rules, by rule name (letters, digits, underscores and hyphens, starting with a letter), at most 1,000:
  - `domain_name` - The DNS namespace forwarded, dot-terminated (`contoso.com.`), or `.` for every name. Changing it replaces the rule.
  - `target_dns_servers` - 1 to 6 DNS servers, `ip_address` and `port` (defaults to `53`), tried in order. Not Azure DNS (`168.63.129.16`).
  - `enabled` - (Optional) Whether the rule applies. Defaults to `true`.
  - `metadata` - (Optional) Metadata on the rule.
- `virtual_network_links` - (Optional) Virtual networks whose queries the rules apply to, by link name, at most 500: `virtual_network_id` (in this region, any subscription of the tenant; changing it replaces the link) and `metadata` (optional). Do not link the virtual network of an inbound endpoint that a rule forwards to: its queries would loop.
- `lock` - (Optional) A lock on the ruleset, as the module's `lock`. Azure applies it to the rules and links too, so the module removes it around their changes.
- `role_assignments` - (Optional) Role assignments on the ruleset, as the module's `role_assignments`.
- `diagnostic_settings` - (Optional) Diagnostic settings on the ruleset, as the module's `diagnostic_settings` (metrics only: a ruleset has no log categories).
DESCRIPTION

  validation {
    condition = alltrue([
      for ruleset in var.forwarding_rulesets : alltrue([
        for endpoint in ruleset.outbound_endpoints :
        contains(keys(var.outbound_endpoints), endpoint) || can(provider::azapi::parse_resource_id("Microsoft.Network/dnsResolvers/outboundEndpoints", endpoint))
      ])
    ])
    error_message = "Each of a ruleset's `outbound_endpoints` must be a key of `outbound_endpoints` or an outbound endpoint resource ID."
  }
  validation {
    condition     = alltrue([for ruleset in var.forwarding_rulesets : ruleset.lock == null ? true : contains(["CanNotDelete", "ReadOnly"], ruleset.lock.kind)])
    error_message = "A ruleset's lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}
