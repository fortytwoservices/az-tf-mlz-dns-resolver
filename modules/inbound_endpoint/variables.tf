variable "location" {
  type        = string
  description = "Azure region of the inbound endpoint: the resolver's."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the inbound endpoint. Changing it replaces the endpoint."
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

variable "private_ip_address" {
  type        = string
  default     = null
  description = "(Optional) A static IPv4 address for the endpoint, inside `subnet_id` and not one of the subnet's five reserved addresses. When null, Azure assigns one dynamically: the subnet's fifth address (`.4` in `10.0.0.0/28`), which changes only if the endpoint is created again. Changing it replaces the endpoint."

  validation {
    condition     = var.private_ip_address == null ? true : can(cidrnetmask("${var.private_ip_address}/32")) # cidrhost would take IPv6 too
    error_message = "`private_ip_address` must be an IPv4 address."
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
  description = "(Optional) Tags of the inbound endpoint."
}
