# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

locals {
  location = "swedencentral"
  tags     = { example = "default" }

  hub_address_space    = "10.0.0.0/24"
  inbound_subnet       = cidrsubnet(local.hub_address_space, 4, 0) # 10.0.0.0/28
  outbound_subnet      = cidrsubnet(local.hub_address_space, 4, 1) # 10.0.0.16/28
  dns_resolver_subnets = { snet-dns-inbound = local.inbound_subnet, snet-dns-outbound = local.outbound_subnet }

  # A resolver and a ruleset have no log categories, only AllMetrics.
  diagnostic_settings = {
    metrics = {
      workspace_resource_id = azapi_resource.log_analytics_workspace.id
      metrics               = [{ category = "AllMetrics" }]
    }
  }
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

  response_export_values = []
  tags                   = local.tags
}

# The hub virtual network with a subnet for each endpoint, delegated to the resolver.
resource "azapi_resource" "hub_virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2025-07-01"
  name      = "vnet-mlz-dnspr-hub-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = [local.hub_address_space] }
      subnets = [for name, prefix in local.dns_resolver_subnets : {
        name = name
        properties = {
          addressPrefix = prefix
          delegations   = [{ name = "Microsoft.Network.dnsResolvers", properties = { serviceName = "Microsoft.Network/dnsResolvers" } }]
        }
      }]
    }
  }

  response_export_values = []
  tags                   = local.tags
}

# Where the resolver and the ruleset send their metrics.
resource "azapi_resource" "log_analytics_workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2025-07-01"
  name      = "log-mlz-dnspr-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      retentionInDays = 30
      sku             = { name = "PerGB2018" }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

# A spoke whose DNS queries for the on-premises zone go through the ruleset.
resource "azapi_resource" "spoke_virtual_network" {
  type      = "Microsoft.Network/virtualNetworks@2025-07-01"
  name      = "vnet-mlz-dnspr-spoke-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.1.0.0/24"] }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

module "dns_resolver" {
  source = "../../"

  name               = "dnspr-mlz-${random_string.suffix.result}"
  parent_id          = azapi_resource.resource_group.id
  location           = local.location
  virtual_network_id = azapi_resource.hub_virtual_network.id
  inbound_endpoints = {
    primary = {
      name      = "in-primary"
      subnet_id = "${azapi_resource.hub_virtual_network.id}/subnets/snet-dns-inbound"
      # Known before apply, so a firewall's DNS proxy or the hub's DNS settings can point at it.
      private_ip_address = cidrhost(local.inbound_subnet, 4)
    }
  }
  outbound_endpoints = {
    primary = {
      name      = "out-primary"
      subnet_id = "${azapi_resource.hub_virtual_network.id}/subnets/snet-dns-outbound"
    }
  }
  forwarding_rulesets = {
    onprem = {
      name               = "dnsfrs-mlz-${random_string.suffix.result}"
      outbound_endpoints = ["primary"]
      rules = {
        onprem = {
          domain_name        = "onprem.example.com."
          target_dns_servers = [{ ip_address = "192.168.0.4" }, { ip_address = "192.168.0.5" }]
        }
      }
      virtual_network_links = {
        spoke = { virtual_network_id = azapi_resource.spoke_virtual_network.id }
      }
      diagnostic_settings = local.diagnostic_settings
    }
  }
  diagnostic_settings = local.diagnostic_settings
  tags                = local.tags
}
