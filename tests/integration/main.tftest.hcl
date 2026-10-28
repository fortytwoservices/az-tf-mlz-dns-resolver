# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# Proves what mocks cannot: the default API versions and bodies are accepted; endpoints, rules and links
# are written in parallel; Azure assigns a dynamic inbound address as Learn says; rules and links update
# in place under the ruleset's ReadOnly lock, and removed values reach Azure; the endpoints and rules
# survive updates of the resolver and the ruleset; an outbound endpoint leaves a ruleset, then is deleted
# under the resolver's lock; and an endpoint is replaced under that lock.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name               = "dnspr-mlz-it-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    virtual_network_id = run.setup.hub_virtual_network_id
    inbound_endpoints = {
      primary   = { name = "in-primary", subnet_id = run.setup.subnet_ids["snet-in-1"], private_ip_address = "10.0.0.4" }
      secondary = { name = "in-secondary", subnet_id = run.setup.subnet_ids["snet-in-2"] }
    }
    outbound_endpoints = {
      primary   = { name = "out-primary", subnet_id = run.setup.subnet_ids["snet-out-1"] }
      secondary = { name = "out-secondary", subnet_id = run.setup.subnet_ids["snet-out-2"] }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-mlz-it-${run.setup.suffix}"
        outbound_endpoints = ["primary", "secondary"]
        rules = {
          contoso   = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }, { ip_address = "10.100.0.5" }] }
          fabrikam  = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }], enabled = false, metadata = { owner = "network" } }
          northwind = { domain_name = "northwind.example.", target_dns_servers = [{ ip_address = "10.100.0.6" }] }
        }
        virtual_network_links = {
          spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"] }
          spoke-2 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"], metadata = { owner = "spoke-2" } }
        }
        lock = { kind = "ReadOnly" }
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    tags = { run = "create" }
  }

  assert {
    condition     = output.inbound_endpoint_ip_addresses["primary"] == "10.0.0.4"
    error_message = "The static inbound address should be the one given, got ${output.inbound_endpoint_ip_addresses["primary"]}."
  }
  assert {
    condition     = output.inbound_endpoint_ip_addresses["secondary"] == "10.0.0.20"
    error_message = "Azure should assign the fifth address of 10.0.0.16/28 dynamically (Learn), got ${output.inbound_endpoint_ip_addresses["secondary"]}."
  }
  assert {
    condition     = length(output.forwarding_rule_resource_ids["onprem"]) == 3 && length(output.virtual_network_link_resource_ids["onprem"]) == 2
    error_message = "All three rules and both links should be created."
  }
}

run "rules_in_azure_after_create" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01"
    ids  = run.create.forwarding_rule_resource_ids["onprem"]
  }

  assert {
    condition     = jsonencode(output.properties["contoso"].targetDnsServers) == jsonencode([{ ipAddress = "10.100.0.4", port = 53 }, { ipAddress = "10.100.0.5", port = 53 }])
    error_message = "Azure should hold the targets in order, got ${jsonencode(output.properties["contoso"].targetDnsServers)}."
  }
  assert {
    condition     = output.properties["fabrikam"].forwardingRuleState == "Disabled" && output.properties["fabrikam"].metadata.owner == "network"
    error_message = "Azure should hold the disabled rule with its metadata."
  }
}

run "update_children_under_readonly_lock" {
  # Rules and links updated in place keep their IDs, and the ruleset's ReadOnly lock blocks the writes:
  # their lock_dependency changes with their body, so the lock is removed and created again around them.
  # Removed metadata and a re-enabled rule must reach Azure.
  variables {
    name               = "dnspr-mlz-it-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    virtual_network_id = run.setup.hub_virtual_network_id
    inbound_endpoints = {
      primary   = { name = "in-primary", subnet_id = run.setup.subnet_ids["snet-in-1"], private_ip_address = "10.0.0.4" }
      secondary = { name = "in-secondary", subnet_id = run.setup.subnet_ids["snet-in-2"] }
    }
    outbound_endpoints = {
      primary   = { name = "out-primary", subnet_id = run.setup.subnet_ids["snet-out-1"] }
      secondary = { name = "out-secondary", subnet_id = run.setup.subnet_ids["snet-out-2"] }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-mlz-it-${run.setup.suffix}"
        outbound_endpoints = ["primary", "secondary"]
        rules = {
          contoso   = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.7" }] }
          fabrikam  = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
          northwind = { domain_name = "northwind.example.", target_dns_servers = [{ ip_address = "10.100.0.6" }] }
        }
        virtual_network_links = {
          spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"], metadata = { owner = "spoke-1" } }
          spoke-2 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"] }
        }
        lock = { kind = "ReadOnly" }
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    tags = { run = "create" }
  }

  assert {
    condition     = output.forwarding_rule_resource_ids["onprem"]["contoso"] == run.create.forwarding_rule_resource_ids["onprem"]["contoso"] && output.virtual_network_link_resource_ids["onprem"]["spoke-2"] == run.create.virtual_network_link_resource_ids["onprem"]["spoke-2"]
    error_message = "The rules and links should be updated in place."
  }
}

run "rules_in_azure_after_update" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01"
    ids  = run.update_children_under_readonly_lock.forwarding_rule_resource_ids["onprem"]
  }

  assert {
    condition     = jsonencode(output.properties["contoso"].targetDnsServers) == jsonencode([{ ipAddress = "10.100.0.7", port = 53 }])
    error_message = "Azure should hold the new targets, got ${jsonencode(output.properties["contoso"].targetDnsServers)}."
  }
  assert {
    condition     = output.properties["fabrikam"].forwardingRuleState == "Enabled" && length(try(output.properties["fabrikam"].metadata, {})) == 0
    error_message = "Azure should hold the rule enabled and without metadata, got ${jsonencode(output.properties["fabrikam"])}."
  }
}

run "links_in_azure_after_update" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01"
    ids  = run.update_children_under_readonly_lock.virtual_network_link_resource_ids["onprem"]
  }

  assert {
    condition     = output.properties["spoke-1"].metadata.owner == "spoke-1" && length(try(output.properties["spoke-2"].metadata, {})) == 0
    error_message = "Azure should hold the added metadata and not the removed one, got ${jsonencode(output.properties)}."
  }
}

run "ruleset_lock_can_not_delete" {
  # The next run updates the ruleset's tags, which its ReadOnly lock would block.
  variables {
    name               = "dnspr-mlz-it-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    virtual_network_id = run.setup.hub_virtual_network_id
    inbound_endpoints = {
      primary   = { name = "in-primary", subnet_id = run.setup.subnet_ids["snet-in-1"], private_ip_address = "10.0.0.4" }
      secondary = { name = "in-secondary", subnet_id = run.setup.subnet_ids["snet-in-2"] }
    }
    outbound_endpoints = {
      primary   = { name = "out-primary", subnet_id = run.setup.subnet_ids["snet-out-1"] }
      secondary = { name = "out-secondary", subnet_id = run.setup.subnet_ids["snet-out-2"] }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-mlz-it-${run.setup.suffix}"
        outbound_endpoints = ["primary", "secondary"]
        rules = {
          contoso   = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.7" }] }
          fabrikam  = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
          northwind = { domain_name = "northwind.example.", target_dns_servers = [{ ip_address = "10.100.0.6" }] }
        }
        virtual_network_links = {
          spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"], metadata = { owner = "spoke-1" } }
          spoke-2 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"] }
        }
        lock = { kind = "CanNotDelete" }
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    tags = { run = "create" }
  }
}

run "update_resolver_and_ruleset" {
  # A tag change writes the resolver, the endpoints and the ruleset, each without its children.
  variables {
    name               = "dnspr-mlz-it-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    virtual_network_id = run.setup.hub_virtual_network_id
    inbound_endpoints = {
      primary   = { name = "in-primary", subnet_id = run.setup.subnet_ids["snet-in-1"], private_ip_address = "10.0.0.4" }
      secondary = { name = "in-secondary", subnet_id = run.setup.subnet_ids["snet-in-2"] }
    }
    outbound_endpoints = {
      primary   = { name = "out-primary", subnet_id = run.setup.subnet_ids["snet-out-1"] }
      secondary = { name = "out-secondary", subnet_id = run.setup.subnet_ids["snet-out-2"] }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-mlz-it-${run.setup.suffix}"
        outbound_endpoints = ["primary", "secondary"]
        rules = {
          contoso   = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.7" }] }
          fabrikam  = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
          northwind = { domain_name = "northwind.example.", target_dns_servers = [{ ip_address = "10.100.0.6" }] }
        }
        virtual_network_links = {
          spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"], metadata = { owner = "spoke-1" } }
          spoke-2 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"] }
        }
        lock = { kind = "CanNotDelete" }
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    tags = { run = "update" }
  }

  assert {
    condition     = azapi_resource.this.tags == tomap({ run = "update" })
    error_message = "The resolver should be updated in place."
  }
}

run "endpoints_survive" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsResolvers/inboundEndpoints@2025-05-01"
    ids  = run.update_resolver_and_ruleset.inbound_endpoint_resource_ids
  }

  assert {
    condition     = length(output.properties) == 2 && output.tags["primary"].run == "update"
    error_message = "The inbound endpoints should survive the resolver update and carry the new tags."
  }
}

run "rules_survive" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01"
    ids  = run.update_resolver_and_ruleset.forwarding_rule_resource_ids["onprem"]
  }

  assert {
    condition     = length(output.properties) == 3
    error_message = "The rules should survive the ruleset update."
  }
}

run "leave_outbound_endpoint" {
  # Azure deletes an outbound endpoint only once no ruleset uses it, and Terraform would delete the endpoint
  # before updating the ruleset: the ruleset leaves it in one apply, and it is deleted in the next.
  variables {
    name               = "dnspr-mlz-it-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    virtual_network_id = run.setup.hub_virtual_network_id
    inbound_endpoints = {
      primary   = { name = "in-primary", subnet_id = run.setup.subnet_ids["snet-in-1"], private_ip_address = "10.0.0.4" }
      secondary = { name = "in-secondary", subnet_id = run.setup.subnet_ids["snet-in-2"] }
    }
    outbound_endpoints = {
      primary   = { name = "out-primary", subnet_id = run.setup.subnet_ids["snet-out-1"] }
      secondary = { name = "out-secondary", subnet_id = run.setup.subnet_ids["snet-out-2"] }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-mlz-it-${run.setup.suffix}"
        outbound_endpoints = ["primary"]
        rules = {
          contoso   = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.7" }] }
          fabrikam  = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
          northwind = { domain_name = "northwind.example.", target_dns_servers = [{ ip_address = "10.100.0.6" }] }
        }
        virtual_network_links = {
          spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"], metadata = { owner = "spoke-1" } }
          spoke-2 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"] }
        }
        lock = { kind = "CanNotDelete" }
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    tags = { run = "update" }
  }

  assert {
    condition     = length(output.outbound_endpoint_resource_ids) == 2
    error_message = "The second outbound endpoint should still exist."
  }
}

run "remove_under_locks" {
  # The outbound endpoint no ruleset uses any more is deleted under the resolver's lock, and a rule and a
  # link under the ruleset's. Both locks are removed and created again around the changes.
  variables {
    name               = "dnspr-mlz-it-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    virtual_network_id = run.setup.hub_virtual_network_id
    inbound_endpoints = {
      primary   = { name = "in-primary", subnet_id = run.setup.subnet_ids["snet-in-1"], private_ip_address = "10.0.0.4" }
      secondary = { name = "in-secondary", subnet_id = run.setup.subnet_ids["snet-in-2"] }
    }
    outbound_endpoints = {
      primary = { name = "out-primary", subnet_id = run.setup.subnet_ids["snet-out-1"] }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-mlz-it-${run.setup.suffix}"
        outbound_endpoints = ["primary"]
        rules = {
          contoso  = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.7" }] }
          fabrikam = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
        }
        virtual_network_links = {
          spoke-2 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"] }
        }
        lock = { kind = "CanNotDelete" }
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    tags = { run = "update" }
  }

  assert {
    condition     = keys(output.outbound_endpoint_resource_ids) == ["primary"] && keys(output.forwarding_rule_resource_ids["onprem"]) == ["contoso", "fabrikam"] && keys(output.virtual_network_link_resource_ids["onprem"]) == ["spoke-2"]
    error_message = "The outbound endpoint, the rule and the link should be gone."
  }
  assert {
    condition     = module.interfaces.lock_resource_id != null && module.forwarding_ruleset["onprem"].lock_resource_id != null
    error_message = "Both locks should be back."
  }
}

run "replace_inbound_endpoint_under_lock" {
  # Azure cannot change an endpoint's address, so a new one replaces the endpoint, under the resolver's
  # lock.
  variables {
    name               = "dnspr-mlz-it-${run.setup.suffix}"
    parent_id          = run.setup.resource_group_id
    location           = run.setup.location
    virtual_network_id = run.setup.hub_virtual_network_id
    inbound_endpoints = {
      primary   = { name = "in-primary", subnet_id = run.setup.subnet_ids["snet-in-1"], private_ip_address = "10.0.0.5" }
      secondary = { name = "in-secondary", subnet_id = run.setup.subnet_ids["snet-in-2"] }
    }
    outbound_endpoints = {
      primary = { name = "out-primary", subnet_id = run.setup.subnet_ids["snet-out-1"] }
    }
    forwarding_rulesets = {
      onprem = {
        name               = "dnsfrs-mlz-it-${run.setup.suffix}"
        outbound_endpoints = ["primary"]
        rules = {
          contoso  = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.7" }] }
          fabrikam = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
        }
        virtual_network_links = {
          spoke-2 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"] }
        }
        lock = { kind = "CanNotDelete" }
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    tags = { run = "update" }
  }

  assert {
    condition     = output.inbound_endpoint_ip_addresses["primary"] == "10.0.0.5" && module.interfaces.lock_resource_id != null
    error_message = "The endpoint should be replaced with the new address, and the lock be back."
  }
}
