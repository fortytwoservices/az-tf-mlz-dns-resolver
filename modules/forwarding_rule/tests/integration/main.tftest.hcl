# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/forwarding_rule
# Proves what mocks cannot: the default API version and body are accepted, targets, state and removed
# metadata are updated in place and reach Azure, and a new domain name replaces the rule.

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
    name               = "contoso"
    parent_id          = run.setup.ruleset_id
    domain_name        = "contoso.example."
    target_dns_servers = [{ ip_address = "10.100.0.4" }, { ip_address = "10.100.0.5" }]
    metadata           = { owner = "network" }
  }
}

run "update_in_place" {
  variables {
    name               = "contoso"
    parent_id          = run.setup.ruleset_id
    domain_name        = "contoso.example."
    target_dns_servers = [{ ip_address = "10.100.0.6" }]
    enabled            = false
  }

  assert {
    condition     = output.resource_id == run.create.resource_id
    error_message = "The rule should be updated in place."
  }
}

run "updated_in_azure" {
  module {
    source = "../../tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01"
    ids  = { rule = run.update_in_place.resource_id }
  }

  assert {
    condition     = jsonencode(output.properties["rule"].targetDnsServers) == jsonencode([{ ipAddress = "10.100.0.6", port = 53 }]) && output.properties["rule"].forwardingRuleState == "Disabled"
    error_message = "Azure should hold the new target and the disabled state, got ${jsonencode(output.properties["rule"])}."
  }
  assert {
    condition     = length(try(output.properties["rule"].metadata, {})) == 0
    error_message = "The removed metadata should be gone from Azure, got ${jsonencode(output.properties["rule"])}."
  }
}

run "replace_with_another_domain" {
  variables {
    name               = "contoso"
    parent_id          = run.setup.ruleset_id
    domain_name        = "corp.contoso.example."
    target_dns_servers = [{ ip_address = "10.100.0.6" }]
  }
}

run "domain_in_azure" {
  module {
    source = "../../tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsForwardingRulesets/forwardingRules@2025-05-01"
    ids  = { rule = run.replace_with_another_domain.resource_id }
  }

  assert {
    condition     = output.properties["rule"].domainName == "corp.contoso.example." && output.properties["rule"].forwardingRuleState == "Enabled"
    error_message = "Azure should hold the new domain, enabled, got ${jsonencode(output.properties["rule"])}."
  }
}
