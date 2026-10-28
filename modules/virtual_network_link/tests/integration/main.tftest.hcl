# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/virtual_network_link
# Proves what mocks cannot: the default API version and body are accepted, removed metadata reaches
# Azure, and another virtual network replaces the link.

run "setup" {
  module {
    source = "../../tests/integration/setup"
  }

  variables {
    parents = "ruleset"
  }
}

run "create" {
  variables {
    name               = "spoke"
    parent_id          = run.setup.ruleset_id
    virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"]
    metadata           = { owner = "spoke-team" }
  }
}

run "remove_metadata" {
  variables {
    name               = "spoke"
    parent_id          = run.setup.ruleset_id
    virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-1"]
  }

  assert {
    condition     = output.resource_id == run.create.resource_id
    error_message = "The link should be updated in place."
  }
}

run "metadata_removed_in_azure" {
  module {
    source = "../../tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01"
    ids  = { link = run.remove_metadata.resource_id }
  }

  assert {
    condition     = length(try(output.properties["link"].metadata, {})) == 0
    error_message = "The removed metadata should be gone from Azure, got ${jsonencode(output.properties["link"])}."
  }
}

run "replace_with_another_virtual_network" {
  variables {
    name               = "spoke"
    parent_id          = run.setup.ruleset_id
    virtual_network_id = run.setup.spoke_virtual_network_ids["vnet-spoke-2"]
  }
}

run "virtual_network_in_azure" {
  module {
    source = "../../tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01"
    ids  = { link = run.replace_with_another_virtual_network.resource_id }
  }

  assert {
    condition     = endswith(lower(output.properties["link"].virtualNetwork.id), "/virtualnetworks/vnet-spoke-2")
    error_message = "Azure should link the new virtual network, got ${output.properties["link"].virtualNetwork.id}."
  }
}
