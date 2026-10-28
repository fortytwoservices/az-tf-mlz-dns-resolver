# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/forwarding_ruleset
# Proves what mocks cannot: the default API version and body are accepted, the ruleset's rules and links
# are written in parallel under its ReadOnly lock and updated or deleted under it (a removed metadata
# entry included, which azapi plans as a version change only), and they survive a tag update of the
# ruleset.

run "setup" {
  module {
    source = "../../tests/integration/setup"
  }

  variables {
    parents = "outbound_endpoint"
  }
}

run "create" {
  variables {
    name                  = "dnsfrs-mlz-it-${run.setup.suffix}"
    parent_id             = run.setup.resource_group_id
    location              = run.setup.location
    outbound_endpoint_ids = [run.setup.outbound_endpoint_id]
    forwarding_rules = {
      contoso  = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.4" }] }
      fabrikam = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.5" }], metadata = { owner = "network", team = "dns" } }
    }
    virtual_network_links = {
      spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"] }
      spoke-2 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"] }
    }
    lock = { kind = "ReadOnly" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }
}

run "update_rule_under_readonly_lock" {
  variables {
    name                  = "dnsfrs-mlz-it-${run.setup.suffix}"
    parent_id             = run.setup.resource_group_id
    location              = run.setup.location
    outbound_endpoint_ids = [run.setup.outbound_endpoint_id]
    forwarding_rules = {
      contoso  = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.6" }] }
      fabrikam = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.5" }], metadata = { owner = "network", team = "dns" } }
    }
    virtual_network_links = {
      spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"] }
    }
    lock = { kind = "ReadOnly" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = output.forwarding_rule_resource_ids["contoso"] == run.create.forwarding_rule_resource_ids["contoso"] && keys(output.virtual_network_link_resource_ids) == ["spoke-1"] && output.lock_resource_id != null
    error_message = "The rule should be updated in place, the link removed, and the lock be back."
  }
}

run "remove_metadata_entry_under_readonly_lock" {
  # The only change: one of two metadata entries removed. azapi plans the body unchanged and only
  # sensitive_body_version changing, so lock_dependency must follow that version for the lock to go.
  variables {
    name                  = "dnsfrs-mlz-it-${run.setup.suffix}"
    parent_id             = run.setup.resource_group_id
    location              = run.setup.location
    outbound_endpoint_ids = [run.setup.outbound_endpoint_id]
    forwarding_rules = {
      contoso  = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.6" }] }
      fabrikam = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.5" }], metadata = { owner = "network" } }
    }
    virtual_network_links = {
      spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"] }
    }
    lock = { kind = "ReadOnly" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = output.forwarding_rule_resource_ids["fabrikam"] == run.create.forwarding_rule_resource_ids["fabrikam"] && output.lock_resource_id != null
    error_message = "The rule should be updated in place under the ReadOnly lock, and the lock be back."
  }
}

run "update_ruleset_tags" {
  # The ruleset's own update needs a lock that is not ReadOnly, so the lock goes.
  variables {
    name                  = "dnsfrs-mlz-it-${run.setup.suffix}"
    parent_id             = run.setup.resource_group_id
    location              = run.setup.location
    outbound_endpoint_ids = [run.setup.outbound_endpoint_id]
    forwarding_rules = {
      contoso  = { domain_name = "contoso.example.", target_dns_servers = [{ ip_address = "10.100.0.6" }] }
      fabrikam = { domain_name = "fabrikam.example.", target_dns_servers = [{ ip_address = "10.100.0.5" }], metadata = { owner = "network" } }
    }
    virtual_network_links = {
      spoke-1 = { virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"] }
    }
    tags = { run = "update" }
  }

  assert {
    condition     = azapi_resource.this.tags == tomap({ run = "update" }) && output.lock_resource_id == null
    error_message = "The ruleset should be updated in place, without its lock."
  }
}

run "rules_survive" {
  module {
    source = "../../tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01"
    ids  = run.update_ruleset_tags.forwarding_rule_resource_ids
  }

  assert {
    condition     = jsonencode(output.properties["contoso"].targetDnsServers) == jsonencode([{ ipAddress = "10.100.0.6", port = 53 }]) && length(output.properties) == 2
    error_message = "The rules should survive the ruleset update with their updated targets."
  }
  assert {
    condition     = jsonencode(output.properties["fabrikam"].metadata) == jsonencode({ owner = "network" })
    error_message = "Azure should hold only the remaining metadata entry, got ${jsonencode(output.properties["fabrikam"].metadata)}."
  }
}
