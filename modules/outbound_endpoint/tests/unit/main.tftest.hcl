mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/outboundEndpoints/out-test"
    }
  }
}

variables {
  name      = "out-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test"
  location  = "swedencentral"
  subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-outbound"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsResolvers/outboundEndpoints@2025-05-01"
    error_message = "The endpoint should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The endpoint should be created with name, parent_id and location."
  }
  assert {
    condition     = azapi_resource.this.body.properties.subnet.id == var.subnet_id
    error_message = "subnet_id should map to properties.subnet.id."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.subnet_id == var.subnet_id
    error_message = "A new subnet should replace the endpoint."
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && length(coalesce(azapi_resource.this.tags, {})) == 0
    error_message = "retry, timeouts and tags should be unset by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && length(output.lock_dependency) == 64
    error_message = "resource_id, name and lock_dependency should come from the endpoint."
  }
}

run "lock_dependency_follows_tags" {
  command = apply

  variables {
    tags = { environment = "test" }
  }

  assert {
    condition     = azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "tags should be set on the endpoint."
  }
  assert {
    condition     = output.lock_dependency != run.defaults.lock_dependency
    error_message = "A tag change is an update a ReadOnly lock blocks, so lock_dependency should change with the tags."
  }
}

run "overrides" {
  command = apply

  variables {
    resource_types      = { network_dns_resolvers_outbound_endpoints = "Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01" }
    ignore_body_changes = { network_dns_resolvers_outbound_endpoints = ["properties.subnet"] }
    retry               = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts            = { create = "30m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01"
    error_message = "resource_types should override the API version."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "30m"
    error_message = "retry and timeouts should be passed to the resource."
  }
}

run "invalid_name" {
  command = plan

  variables {
    name = "-out"
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

run "invalid_subnet_id" {
  command = plan

  variables {
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test"
  }

  expect_failures = [var.subnet_id]
}
