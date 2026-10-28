variable "location" {
  type        = string
  description = "Azure region of the outbound endpoint: the resolver's."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the outbound endpoint. Changing it replaces the endpoint."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9_-]{0,78}[a-zA-Z0-9])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, underscores and hyphens, starting and ending with a letter or digit."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the DNS private resolver that holds the endpoint."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/dnsResolvers", var.parent_id))
    error_message = "`parent_id` must be a DNS private resolver resource ID."
  }
}

variable "subnet_id" {
  type        = string
  description = "Resource ID of the endpoint's subnet: in the resolver's virtual network, /28 to /24, delegated to `Microsoft.Network/dnsResolvers`, and used by no other endpoint or service. Changing it replaces the endpoint."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Network/virtualNetworks/subnets", var.subnet_id))
    error_message = "`subnet_id` must be a subnet resource ID."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the outbound endpoint."
}
