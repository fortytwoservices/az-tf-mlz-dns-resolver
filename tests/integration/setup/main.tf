# A resource group for one integration test run, with a hub virtual network whose four subnets are
# delegated to DNS resolvers, two spoke virtual networks, and, for the submodules' tests, the parents
# they need: a resolver, an outbound endpoint and a ruleset. Called by the root's and every submodule's
# integration tests.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "parents" {
  type        = string
  default     = "none"
  description = "The parents to create: `none`, `resolver`, `outbound_endpoint` (the resolver and an outbound endpoint) or `ruleset` (those and a ruleset)."

  validation {
    condition     = contains(["none", "resolver", "outbound_endpoint", "ruleset"], var.parents)
    error_message = "`parents` must be none, resolver, outbound_endpoint or ruleset."
  }
}

locals {
  location = "swedencentral"
  # Azure reports endpoints deleted before the resolver stops counting them as nested resources.
  retry = { error_message_regex = ["AnotherOperationInProgress", "CannotDeleteResource"] }
  # snet-in-1 10.0.0.0/28, snet-in-2 10.0.0.16/28, snet-out-1 10.0.0.32/28, snet-out-2 10.0.0.48/28
  subnets = { for index, name in ["snet-in-1", "snet-in-2", "snet-out-1", "snet-out-2"] : name => cidrsubnet("10.0.0.0/24", 4, index) }

  resolver          = contains(["resolver", "outbound_endpoint", "ruleset"], var.parents)
  outbound_endpoint = contains(["outbound_endpoint", "ruleset"], var.parents)
  ruleset           = var.parents == "ruleset"
}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-dnspr-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location
}

resource "azapi_resource" "hub" {
  type      = "Microsoft.Network/virtualNetworks@2025-07-01"
  name      = "vnet-hub"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  retry     = local.retry
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.0.0.0/24"] }
      subnets = [for name, prefix in local.subnets : {
        name = name
        properties = {
          addressPrefix = prefix
          delegations   = [{ name = "Microsoft.Network.dnsResolvers", properties = { serviceName = "Microsoft.Network/dnsResolvers" } }]
        }
      }]
    }
  }
}

resource "azapi_resource" "spoke" {
  for_each = { vnet-spoke-1 = "10.1.0.0/24", vnet-spoke-2 = "10.2.0.0/24" }

  type      = "Microsoft.Network/virtualNetworks@2025-07-01"
  name      = each.key
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  retry     = local.retry
  body = {
    properties = {
      addressSpace = { addressPrefixes = [each.value] }
    }
  }
}

resource "azapi_resource" "resolver" {
  count = local.resolver ? 1 : 0

  type      = "Microsoft.Network/dnsResolvers@2025-05-01"
  name      = "dnspr-setup"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  retry     = local.retry
  body = {
    properties = {
      virtualNetwork = { id = azapi_resource.hub.id }
    }
  }
}

resource "azapi_resource" "outbound_endpoint" {
  count = local.outbound_endpoint ? 1 : 0

  type      = "Microsoft.Network/dnsResolvers/outboundEndpoints@2025-05-01"
  name      = "out-setup"
  parent_id = azapi_resource.resolver[0].id
  location  = local.location
  retry     = local.retry
  body = {
    properties = {
      subnet = { id = "${azapi_resource.hub.id}/subnets/snet-out-1" }
    }
  }
}

resource "azapi_resource" "ruleset" {
  count = local.ruleset ? 1 : 0

  type      = "Microsoft.Network/dnsForwardingRulesets@2025-05-01"
  name      = "dnsfrs-setup"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  retry     = local.retry
  body = {
    properties = {
      dnsResolverOutboundEndpoints = [{ id = azapi_resource.outbound_endpoint[0].id }]
    }
  }
}

output "hub_virtual_network_id" {
  value = azapi_resource.hub.id
}

output "location" {
  value = local.location
}

output "object_id" {
  value = data.azapi_client_config.current.object_id
}

output "outbound_endpoint_id" {
  value = one(azapi_resource.outbound_endpoint[*].id)
}

output "resolver_id" {
  value = one(azapi_resource.resolver[*].id)
}

output "resource_group_id" {
  value = azapi_resource.resource_group.id
}

output "ruleset_id" {
  value = one(azapi_resource.ruleset[*].id)
}

output "spoke_virtual_network_ids" {
  value = { for name, spoke in azapi_resource.spoke : name => spoke.id }
}

output "subnet_ids" {
  value = { for name, _ in local.subnets : name => "${azapi_resource.hub.id}/subnets/${name}" }
}

output "suffix" {
  value = random_string.suffix.result
}
