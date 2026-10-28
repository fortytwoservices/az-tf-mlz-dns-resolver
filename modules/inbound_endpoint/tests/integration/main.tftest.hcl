# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/inbound_endpoint
# Proves what mocks cannot: the default API version and body are accepted, Azure assigns the subnet's
# fifth address dynamically, tags update in place, and a static address replaces the endpoint.

run "setup" {
  module {
    source = "../../tests/integration/setup"
  }

  variables {
    parents = "resolver"
  }
}

run "create_dynamic" {
  variables {
    name      = "in-mlz-it"
    parent_id = run.setup.resolver_id
    location  = run.setup.location
    subnet_id = run.setup.subnet_ids["snet-in-1"]
  }

  assert {
    condition     = output.private_ip_address == "10.0.0.4"
    error_message = "Azure should assign the fifth address of 10.0.0.0/28, got ${output.private_ip_address}."
  }
}

run "update_tags" {
  variables {
    name      = "in-mlz-it"
    parent_id = run.setup.resolver_id
    location  = run.setup.location
    subnet_id = run.setup.subnet_ids["snet-in-1"]
    tags      = { run = "update" }
  }

  assert {
    condition     = output.private_ip_address == "10.0.0.4" && azapi_resource.this.tags == tomap({ run = "update" })
    error_message = "A tag change should update the endpoint in place and keep its address."
  }
}

run "replace_with_static_address" {
  variables {
    name               = "in-mlz-it"
    parent_id          = run.setup.resolver_id
    location           = run.setup.location
    subnet_id          = run.setup.subnet_ids["snet-in-1"]
    private_ip_address = "10.0.0.6"
    tags               = { run = "update" }
  }

  assert {
    condition     = output.private_ip_address == "10.0.0.6"
    error_message = "The endpoint should be created again with the static address, got ${output.private_ip_address}."
  }
}
