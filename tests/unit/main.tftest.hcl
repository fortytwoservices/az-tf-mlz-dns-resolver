mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      # A ruleset ID: the rules and links validate their parent. The resolver and outbound endpoints get
      # their own IDs below.
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsForwardingRulesets/dnsfrs-test"
      output = {
        properties = {
          ipConfigurations = [{ privateIpAddress = "10.0.0.4" }]
        }
      }
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          }
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

# Mocked resources all share one ID, and the endpoints and rulesets validate their parents. An override
# of a resource inside a for_each module is ignored (Terraform 1.17.0), so the outbound endpoints are
# overridden as a module; their own tests cover their resource.
override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test"
  }
}

override_module {
  target = module.outbound_endpoint
  outputs = {
    lock_dependency = "0000000000000000000000000000000000000000000000000000000000000000"
    name            = "out-primary"
    resource_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/outboundEndpoints/out-primary"
  }
}

variables {
  name               = "dnspr-test"
  parent_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  location           = "swedencentral"
  virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsResolvers@2025-05-01"
    error_message = "The resolver should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The resolver should be created with name, parent_id and location."
  }
  assert {
    condition     = azapi_resource.this.body.properties.virtualNetwork.id == var.virtual_network_id && azapi_resource.this.replace_triggers_external_values.virtual_network_id == var.virtual_network_id
    error_message = "virtual_network_id should map to properties.virtualNetwork.id, and another virtual network should replace the resolver."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress", "CannotDeleteResource"]) && azapi_resource.this.retry.interval_seconds == 30 && azapi_resource.this.retry.max_interval_seconds == 300
    error_message = "The default retry should cover AnotherOperationInProgress and CannotDeleteResource."
  }
  assert {
    condition     = azapi_resource.this.timeouts == null && length(coalesce(azapi_resource.this.tags, {})) == 0
    error_message = "timeouts and tags should be unset by default."
  }
  assert {
    condition     = module.interfaces.lock_resource_id == null && length(module.interfaces.role_assignment_resource_ids) == 0
    error_message = "No lock or role assignment should be created by default."
  }
  assert {
    condition     = length(module.inbound_endpoint) + length(module.outbound_endpoint) + length(module.forwarding_ruleset) == 0
    error_message = "No endpoint or ruleset should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name
    error_message = "resource_id and name should come from the resolver."
  }
  assert {
    condition = (
      length(output.inbound_endpoint_ip_addresses) + length(output.inbound_endpoint_resource_ids) + length(output.outbound_endpoint_resource_ids) +
      length(output.forwarding_ruleset_resource_ids) + length(output.forwarding_rule_resource_ids) + length(output.virtual_network_link_resource_ids) == 0
    )
    error_message = "The endpoint and ruleset outputs should be empty by default."
  }
}

run "endpoints_and_rulesets" {
  command = apply

  variables {
    inbound_endpoints = {
      primary   = { name = "in-primary", subnet_id = "${var.virtual_network_id}/subnets/snet-inbound", private_ip_address = "10.0.0.4" }
      secondary = { name = "in-secondary", subnet_id = "${var.virtual_network_id}/subnets/snet-inbound-2" }
    }
    outbound_endpoints = {
      primary = { name = "out-primary", subnet_id = "${var.virtual_network_id}/subnets/snet-outbound" }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-onprem"
        outbound_endpoints = ["primary"]
        rules = {
          contoso = { domain_name = "contoso.com.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
        }
        virtual_network_links = {
          spoke = { virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-spoke/providers/Microsoft.Network/virtualNetworks/vnet-spoke" }
        }
        lock = { kind = "CanNotDelete" }
      }
      other_resolver = {
        name               = "dnsfrs-other"
        outbound_endpoints = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-other/providers/Microsoft.Network/dnsResolvers/dnspr-other/outboundEndpoints/out-other"]
      }
    }
    tags = { environment = "test" }
  }

  assert {
    condition     = keys(module.inbound_endpoint) == ["primary", "secondary"] && module.inbound_endpoint["primary"].name == "in-primary"
    error_message = "One inbound endpoint module should be created per entry, with its name."
  }
  assert {
    condition     = keys(module.outbound_endpoint) == ["primary"] && module.outbound_endpoint["primary"].name == "out-primary"
    error_message = "One outbound endpoint module should be created per entry, with its name."
  }
  assert {
    condition     = keys(module.forwarding_ruleset) == ["onprem", "other_resolver"] && module.forwarding_ruleset["onprem"].name == "dnsfrs-onprem"
    error_message = "One ruleset module should be created per entry, with its name."
  }
  assert {
    condition     = output.inbound_endpoint_ip_addresses["primary"] == "10.0.0.4" && output.inbound_endpoint_ip_addresses["secondary"] == "10.0.0.4"
    error_message = "inbound_endpoint_ip_addresses should come from the endpoints, by key."
  }
  assert {
    condition     = keys(output.inbound_endpoint_resource_ids) == ["primary", "secondary"] && keys(output.outbound_endpoint_resource_ids) == ["primary"]
    error_message = "Endpoint resource IDs should be output by key."
  }
  assert {
    condition     = keys(output.forwarding_ruleset_resource_ids) == ["onprem", "other_resolver"]
    error_message = "Ruleset resource IDs should be output by key."
  }
  assert {
    condition     = keys(output.forwarding_rule_resource_ids["onprem"]) == ["contoso"] && length(output.forwarding_rule_resource_ids["other_resolver"]) == 0
    error_message = "Rule resource IDs should be output by ruleset key, then rule name."
  }
  assert {
    condition     = keys(output.virtual_network_link_resource_ids["onprem"]) == ["spoke"] && length(output.virtual_network_link_resource_ids["other_resolver"]) == 0
    error_message = "Link resource IDs should be output by ruleset key, then link name."
  }
  assert {
    condition     = module.forwarding_ruleset["onprem"].lock_resource_id != null && module.forwarding_ruleset["other_resolver"].lock_resource_id == null
    error_message = "A ruleset's lock should reach that ruleset only."
  }
  assert {
    condition     = module.interfaces.lock_resource_id == null
    error_message = "A ruleset's lock should not lock the resolver."
  }
  assert {
    condition     = azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "tags should be set on the resolver."
  }
}

run "interfaces" {
  command = apply

  variables {
    inbound_endpoints = {
      primary = { name = "in-primary", subnet_id = "${var.virtual_network_id}/subnets/snet-inbound" }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        role_definition_id_or_name = "Reader"
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
    condition     = module.interfaces.lock_resource_id != null && keys(module.interfaces.role_assignment_resource_ids) == ["reader"]
    error_message = "The lock and role assignments should be created through az-tf-mlz-interfaces."
  }
}

run "azapi_settings_reach_every_resource" {
  command = apply

  # ignore_body_changes is write-only, so a test cannot read it back, and avm_interface_ignore_body_changes
  # only checks that the argument uses the variable, not which slot. Setting every slot proves the shape
  # is accepted; which resource reads which slot is left to review.
  variables {
    inbound_endpoints = {
      primary = { name = "in-primary", subnet_id = "${var.virtual_network_id}/subnets/snet-inbound" }
    }
    outbound_endpoints = {
      primary = { name = "out-primary", subnet_id = "${var.virtual_network_id}/subnets/snet-outbound" }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-onprem"
        outbound_endpoints = ["primary"]
        rules = {
          contoso = { domain_name = "contoso.com.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
        }
      }
    }
    resource_types = {
      network_dns_resolvers                    = "Microsoft.Network/dnsResolvers@2022-07-01"
      authorization_locks                      = "Microsoft.Authorization/locks@2016-09-01"
      authorization_role_assignments           = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
      network_dns_resolvers_inbound_endpoints  = { network_dns_resolvers_inbound_endpoints = "Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01" }
      network_dns_resolvers_outbound_endpoints = { network_dns_resolvers_outbound_endpoints = "Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01" }
      network_dns_forwarding_rulesets = {
        network_dns_forwarding_rulesets                       = "Microsoft.Network/dnsForwardingRulesets@2022-07-01"
        network_dns_forwarding_rulesets_forwarding_rules      = { network_dns_forwarding_rulesets_forwarding_rules = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01" }
        network_dns_forwarding_rulesets_virtual_network_links = { network_dns_forwarding_rulesets_virtual_network_links = "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01" }
      }
    }
    ignore_body_changes = {
      network_dns_resolvers                    = ["properties.virtualNetwork"]
      network_dns_resolvers_inbound_endpoints  = { network_dns_resolvers_inbound_endpoints = ["properties.ipConfigurations"] }
      network_dns_resolvers_outbound_endpoints = { network_dns_resolvers_outbound_endpoints = ["properties.subnet"] }
      network_dns_forwarding_rulesets = {
        network_dns_forwarding_rulesets                  = ["properties.dnsResolverOutboundEndpoints"]
        network_dns_forwarding_rulesets_forwarding_rules = { network_dns_forwarding_rulesets_forwarding_rules = ["properties.metadata"] }
      }
    }
    retry = {
      error_message_regex = ["AnotherOperationInProgress", "Conflict"]
    }
    timeouts = {
      create = "45m"
    }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsResolvers@2022-07-01"
    error_message = "The resource_types override should reach the resolver."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress", "Conflict"]) && azapi_resource.this.timeouts.create == "45m"
    error_message = "retry and timeouts should reach the resolver."
  }
}

run "invalid_name" {
  command = plan

  variables {
    name = "dnspr-"
  }

  expect_failures = [var.name]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "invalid_virtual_network_id" {
  command = plan

  variables {
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.virtual_network_id]
}

run "inbound_subnet_in_another_virtual_network" {
  command = plan

  variables {
    inbound_endpoints = {
      primary = { name = "in-primary", subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub-2/subnets/snet-inbound" }
    }
  }

  expect_failures = [var.inbound_endpoints]
}

run "six_inbound_endpoints" {
  command = plan

  variables {
    inbound_endpoints = { for i in range(6) : "e${i}" => { name = "in-${i}", subnet_id = "${var.virtual_network_id}/subnets/snet-in-${i}" } }
  }

  expect_failures = [var.inbound_endpoints]
}

run "outbound_subnet_in_another_virtual_network" {
  command = plan

  variables {
    outbound_endpoints = {
      primary = { name = "out-primary", subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-hub-2/subnets/snet-outbound" }
    }
  }

  expect_failures = [var.outbound_endpoints]
}

run "shared_subnet" {
  command = plan

  variables {
    inbound_endpoints = {
      primary = { name = "in-primary", subnet_id = "${var.virtual_network_id}/subnets/snet-dns" }
    }
    outbound_endpoints = {
      primary = { name = "out-primary", subnet_id = "${var.virtual_network_id}/subnets/SNET-DNS" }
    }
  }

  expect_failures = [var.outbound_endpoints]
}

run "unknown_outbound_endpoint_key" {
  command = plan

  variables {
    outbound_endpoints = {
      primary = { name = "out-primary", subnet_id = "${var.virtual_network_id}/subnets/snet-outbound" }
    }
    forwarding_rulesets = {
      onprem = { name = "dnsfrs-onprem", outbound_endpoints = ["secondary"] }
    }
  }

  expect_failures = [var.forwarding_rulesets]
}

run "invalid_ruleset_lock_kind" {
  command = plan

  variables {
    outbound_endpoints = {
      primary = { name = "out-primary", subnet_id = "${var.virtual_network_id}/subnets/snet-outbound" }
    }
    forwarding_rulesets = {
      onprem = { name = "dnsfrs-onprem", outbound_endpoints = ["primary"], lock = { kind = "Delete" } }
    }
  }

  expect_failures = [var.forwarding_rulesets]
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
