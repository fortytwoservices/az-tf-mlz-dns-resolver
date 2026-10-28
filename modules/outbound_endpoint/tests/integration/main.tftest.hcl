# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/outbound_endpoint
# Proves what mocks cannot: the default API version and body are accepted, tags update in place, and a
# new subnet replaces the endpoint.

run "setup" {
  module {
    source = "../../tests/integration/setup"
  }

  variables {
    parents = "resolver"
  }
}

run "create" {
  variables {
    name      = "out-mlz-it"
    parent_id = run.setup.resolver_id
    location  = run.setup.location
    subnet_id = run.setup.subnet_ids["snet-out-1"]
  }
}

run "update_tags" {
  variables {
    name      = "out-mlz-it"
    parent_id = run.setup.resolver_id
    location  = run.setup.location
    subnet_id = run.setup.subnet_ids["snet-out-1"]
    tags      = { run = "update" }
  }

  assert {
    condition     = azapi_resource.this.tags == tomap({ run = "update" })
    error_message = "A tag change should update the endpoint in place."
  }
}

run "replace_with_another_subnet" {
  variables {
    name      = "out-mlz-it"
    parent_id = run.setup.resolver_id
    location  = run.setup.location
    subnet_id = run.setup.subnet_ids["snet-out-2"]
    tags      = { run = "update" }
  }
}

run "subnet_in_azure" {
  module {
    source = "../../tests/integration/read"
  }

  variables {
    type = "Microsoft.Network/dnsResolvers/outboundEndpoints@2025-05-01"
    ids  = { endpoint = run.replace_with_another_subnet.resource_id }
  }

  assert {
    condition     = endswith(lower(output.properties["endpoint"].subnet.id), "/subnets/snet-out-2")
    error_message = "Azure should hold the endpoint in the new subnet, got ${output.properties["endpoint"].subnet.id}."
  }
}
