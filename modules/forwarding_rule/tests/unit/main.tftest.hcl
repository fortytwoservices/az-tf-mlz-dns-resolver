mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsForwardingRulesets/dnsfrs-test/forwardingRules/contoso"
    }
  }
}

variables {
  name               = "contoso"
  parent_id          = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsForwardingRulesets/dnsfrs-test"
  domain_name        = "contoso.com."
  target_dns_servers = [{ ip_address = "10.100.0.4" }, { ip_address = "10.100.0.5", port = 53 }]
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01"
    error_message = "The rule should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id
    error_message = "The rule should be created with name and parent_id."
  }
  assert {
    condition     = azapi_resource.this.body.properties.domainName == "contoso.com." && azapi_resource.this.body.properties.forwardingRuleState == "Enabled"
    error_message = "domain_name should map to properties.domainName, and the rule should be enabled by default."
  }
  assert {
    condition = jsonencode(azapi_resource.this.body.properties.targetDnsServers) == jsonencode([
      { ipAddress = "10.100.0.4", port = 53 },
      { ipAddress = "10.100.0.5", port = 53 },
    ])
    error_message = "target_dns_servers should be sent in order, with port 53."
  }
  assert {
    condition     = azapi_resource.this.body.properties.metadata == null
    error_message = "Empty metadata should be sent as null, so that removing the last entry reaches Azure."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.domain_name == "contoso.com."
    error_message = "A new domain name should replace the rule."
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null
    error_message = "retry and timeouts should be unset by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && length(output.lock_dependency) == 64
    error_message = "resource_id, name and lock_dependency should come from the rule."
  }
}

run "disabled_with_metadata" {
  command = apply

  variables {
    enabled  = false
    metadata = { owner = "network" }
  }

  assert {
    condition     = azapi_resource.this.body.properties.forwardingRuleState == "Disabled" && azapi_resource.this.body.properties.metadata.owner == "network"
    error_message = "enabled = false should send Disabled, and metadata should be sent."
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

run "wildcard" {
  command = apply

  variables {
    domain_name = "."
  }

  assert {
    condition     = azapi_resource.this.body.properties.domainName == "."
    error_message = "A wildcard rule should be accepted."
  }
}

run "overrides" {
  command = apply

  variables {
    resource_types      = { network_dns_forwarding_rulesets_forwarding_rules = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01" }
    ignore_body_changes = { network_dns_forwarding_rulesets_forwarding_rules = ["properties.metadata"] }
    retry               = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts            = { create = "10m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01"
    error_message = "resource_types should override the API version."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "10m"
    error_message = "retry and timeouts should be passed to the resource."
  }
}

run "domain_without_trailing_dot" {
  command = plan

  variables {
    domain_name = "contoso.com"
  }

  expect_failures = [var.domain_name]
}

run "domain_with_empty_label" {
  command = plan

  variables {
    domain_name = "contoso..com."
  }

  expect_failures = [var.domain_name]
}

run "no_target" {
  command = plan

  variables {
    target_dns_servers = []
  }

  expect_failures = [var.target_dns_servers]
}

run "seven_targets" {
  command = plan

  variables {
    target_dns_servers = [for i in range(7) : { ip_address = "10.100.0.${i + 4}" }]
  }

  expect_failures = [var.target_dns_servers]
}

run "azure_dns_target" {
  command = plan

  variables {
    target_dns_servers = [{ ip_address = "168.63.129.16" }]
  }

  expect_failures = [var.target_dns_servers]
}

run "port_other_than_53" {
  command = plan

  variables {
    target_dns_servers = [{ ip_address = "10.100.0.4", port = 5353 }]
  }

  expect_failures = [var.target_dns_servers]
}

run "ipv6_target" {
  command = plan

  variables {
    target_dns_servers = [{ ip_address = "2001:db8::4" }]
  }

  expect_failures = [var.target_dns_servers]
}

run "invalid_name" {
  command = plan

  variables {
    name = "1contoso"
  }

  expect_failures = [var.name]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.parent_id]
}
