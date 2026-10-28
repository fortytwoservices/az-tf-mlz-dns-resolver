mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsForwardingRulesets/dnsfrs-test"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7"
            role_name = "Network Contributor"
          }
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

variables {
  name                  = "dnsfrs-test"
  parent_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  location              = "swedencentral"
  outbound_endpoint_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/outboundEndpoints/out-test"]
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsForwardingRulesets@2025-05-01"
    error_message = "The ruleset should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The ruleset should be created with name, parent_id and location."
  }
  assert {
    condition     = jsonencode(azapi_resource.this.body.properties.dnsResolverOutboundEndpoints) == jsonencode([for id in var.outbound_endpoint_ids : { id = id }])
    error_message = "outbound_endpoint_ids should map to properties.dnsResolverOutboundEndpoints, in order."
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && length(coalesce(azapi_resource.this.tags, {})) == 0
    error_message = "retry, timeouts and tags should be unset by default."
  }
  assert {
    condition     = module.interfaces.lock_resource_id == null && length(module.interfaces.role_assignment_resource_ids) + length(module.forwarding_rule) + length(module.virtual_network_link) == 0
    error_message = "No lock, role assignment, rule or link should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && output.lock_resource_id == null
    error_message = "resource_id and name should come from the ruleset, and lock_resource_id be null without a lock."
  }
  assert {
    condition     = length(output.forwarding_rule_resource_ids) + length(output.virtual_network_link_resource_ids) + length(output.role_assignment_resource_ids) == 0
    error_message = "No rule, link or role assignment IDs should be output by default."
  }
}

run "rules_and_links" {
  command = apply

  variables {
    outbound_endpoint_ids = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/outboundEndpoints/out-b",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/outboundEndpoints/out-a",
    ]
    forwarding_rules = {
      contoso  = { domain_name = "contoso.com.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
      fabrikam = { domain_name = "fabrikam.com.", target_dns_servers = [{ ip_address = "10.100.0.5" }], enabled = false }
    }
    virtual_network_links = {
      spoke = { virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-spoke/providers/Microsoft.Network/virtualNetworks/vnet-spoke" }
    }
    lock = { kind = "CanNotDelete" }
    tags = { environment = "test" }
  }

  assert {
    condition     = azapi_resource.this.body.properties.dnsResolverOutboundEndpoints[0].id == var.outbound_endpoint_ids[0]
    error_message = "The outbound endpoints should be sent in the order given, not sorted."
  }
  assert {
    condition     = keys(module.forwarding_rule) == ["contoso", "fabrikam"] && module.forwarding_rule["contoso"].name == "contoso"
    error_message = "One rule module should be created per rule, named by its key."
  }
  assert {
    condition     = keys(module.virtual_network_link) == ["spoke"] && module.virtual_network_link["spoke"].name == "spoke"
    error_message = "One link module should be created per link, named by its key."
  }
  assert {
    condition     = keys(output.forwarding_rule_resource_ids) == ["contoso", "fabrikam"] && keys(output.virtual_network_link_resource_ids) == ["spoke"]
    error_message = "Rule and link resource IDs should be output by name."
  }
  assert {
    condition     = output.lock_resource_id != null && azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "The lock and tags should be set on the ruleset."
  }
}

run "interfaces" {
  command = apply

  variables {
    lock = { kind = "ReadOnly" }
    role_assignments = {
      spoke_team = {
        role_definition_id_or_name = "Network Contributor"
        principal_id               = "55555555-5555-5555-5555-555555555555"
      }
    }
    diagnostic_settings = {
      metrics = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
        metrics               = [{ category = "AllMetrics" }]
      }
    }
  }

  # Their behaviour is tested in az-tf-mlz-interfaces; a test sees only its outputs.
  assert {
    condition     = keys(module.interfaces.diagnostic_setting_resource_ids) == ["metrics"]
    error_message = "Diagnostic settings should be created through az-tf-mlz-interfaces."
  }
  assert {
    condition     = module.interfaces.lock_resource_id != null && keys(module.interfaces.role_assignment_resource_ids) == ["spoke_team"]
    error_message = "The lock and role assignments should be created through az-tf-mlz-interfaces."
  }
  assert {
    condition     = keys(output.role_assignment_resource_ids) == ["spoke_team"]
    error_message = "Role assignment resource IDs should be output by key."
  }
}

run "azapi_settings_reach_every_resource" {
  command = apply

  # ignore_body_changes is write-only, so a test cannot read it back; which resource reads which slot is
  # left to review. Setting every slot proves the shape is accepted.
  variables {
    forwarding_rules = {
      contoso = { domain_name = "contoso.com.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
    }
    virtual_network_links = {
      spoke = { virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-spoke/providers/Microsoft.Network/virtualNetworks/vnet-spoke" }
    }
    resource_types = {
      network_dns_forwarding_rulesets                       = "Microsoft.Network/dnsForwardingRulesets@2022-07-01"
      network_dns_forwarding_rulesets_forwarding_rules      = { network_dns_forwarding_rulesets_forwarding_rules = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01" }
      network_dns_forwarding_rulesets_virtual_network_links = { network_dns_forwarding_rulesets_virtual_network_links = "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01" }
    }
    ignore_body_changes = {
      network_dns_forwarding_rulesets                       = ["properties.dnsResolverOutboundEndpoints"]
      network_dns_forwarding_rulesets_forwarding_rules      = { network_dns_forwarding_rulesets_forwarding_rules = ["properties.metadata"] }
      network_dns_forwarding_rulesets_virtual_network_links = { network_dns_forwarding_rulesets_virtual_network_links = ["properties.metadata"] }
    }
    retry    = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts = { create = "15m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsForwardingRulesets@2022-07-01"
    error_message = "The resource_types override should reach the ruleset."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "15m"
    error_message = "retry and timeouts should reach the ruleset."
  }
}

run "no_outbound_endpoint" {
  command = plan

  variables {
    outbound_endpoint_ids = []
  }

  expect_failures = [var.outbound_endpoint_ids]
}

run "three_outbound_endpoints" {
  command = plan

  variables {
    outbound_endpoint_ids = [for name in ["a", "b", "c"] : "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/outboundEndpoints/out-${name}"]
  }

  expect_failures = [var.outbound_endpoint_ids]
}

run "duplicate_outbound_endpoint" {
  command = plan

  variables {
    outbound_endpoint_ids = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/outboundEndpoints/out-a",
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/RG-TEST/providers/Microsoft.Network/dnsResolvers/dnspr-test/outboundEndpoints/out-a",
    ]
  }

  expect_failures = [var.outbound_endpoint_ids]
}

run "inbound_endpoint_as_outbound" {
  command = plan

  variables {
    outbound_endpoint_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/inboundEndpoints/in-a"]
  }

  expect_failures = [var.outbound_endpoint_ids]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "invalid_lock_kind" {
  command = plan

  variables {
    lock = { kind = "Delete" }
  }

  expect_failures = [var.lock]
}

run "diagnostic_logs" {
  command = plan

  variables {
    diagnostic_settings = {
      logs = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/law-test"
        logs                  = [{ category_group = "allLogs" }]
      }
    }
  }

  expect_failures = [var.diagnostic_settings]
}
