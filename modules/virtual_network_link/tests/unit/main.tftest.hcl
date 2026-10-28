mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsForwardingRulesets/dnsfrs-test/virtualNetworkLinks/spoke"
    }
  }
}

variables {
  name               = "spoke"
  parent_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsForwardingRulesets/dnsfrs-test"
  virtual_network_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-spoke/providers/Microsoft.Network/virtualNetworks/vnet-spoke"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2025-05-01"
    error_message = "The link should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id
    error_message = "The link should be created with name and parent_id."
  }
  assert {
    condition     = azapi_resource.this.body.properties.virtualNetwork.id == var.virtual_network_id && azapi_resource.this.body.properties.metadata == null
    error_message = "virtual_network_id should map to properties.virtualNetwork.id, and empty metadata be sent as null so that removing the last entry reaches Azure."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.virtual_network_id == var.virtual_network_id
    error_message = "Another virtual network should replace the link."
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null
    error_message = "retry and timeouts should be unset by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && length(output.lock_dependency) == 64
    error_message = "resource_id, name and lock_dependency should come from the link."
  }
}

run "metadata" {
  command = apply

  variables {
    metadata = { owner = "spoke-team" }
  }

  assert {
    condition     = azapi_resource.this.body.properties.metadata.owner == "spoke-team"
    error_message = "metadata should be sent."
  }
  assert {
    condition     = output.lock_dependency != run.defaults.lock_dependency
    error_message = "lock_dependency should change with the body."
  }
  assert {
    condition     = azapi_resource.this.sensitive_body_version["properties.metadata"] == sha256(jsonencode(var.metadata)) && azapi_resource.this.sensitive_body_version["properties.metadata"] != sha256(jsonencode({}))
    error_message = "A metadata change should change the version that sends the metadata again, so that removing one entry reaches Azure."
  }
}

run "overrides" {
  command = apply

  variables {
    resource_types      = { network_dns_forwarding_rulesets_virtual_network_links = "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01" }
    ignore_body_changes = { network_dns_forwarding_rulesets_virtual_network_links = ["properties.metadata"] }
    retry               = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts            = { create = "10m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01"
    error_message = "resource_types should override the API version."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "10m"
    error_message = "retry and timeouts should be passed to the resource."
  }
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.parent_id]
}

run "invalid_virtual_network_id" {
  command = plan

  variables {
    virtual_network_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet"
  }

  expect_failures = [var.virtual_network_id]
}
