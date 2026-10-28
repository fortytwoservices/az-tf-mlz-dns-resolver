mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test/inboundEndpoints/in-test"
      output = {
        properties = {
          ipConfigurations = [{ privateIpAddress = "10.0.0.4" }]
        }
      }
    }
  }
}

variables {
  name      = "in-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsResolvers/dnspr-test"
  location  = "swedencentral"
  subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/snet-inbound"
}

run "dynamic_address" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsResolvers/inboundEndpoints@2025-05-01"
    error_message = "The endpoint should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The endpoint should be created with name, parent_id and location."
  }
  assert {
    condition     = length(azapi_resource.this.body.properties.ipConfigurations) == 1 && azapi_resource.this.body.properties.ipConfigurations[0].subnet.id == var.subnet_id
    error_message = "The endpoint should have one IP configuration in subnet_id."
  }
  assert {
    condition     = azapi_resource.this.body.properties.ipConfigurations[0].privateIpAllocationMethod == "Dynamic" && !can(azapi_resource.this.body.properties.ipConfigurations[0].privateIpAddress)
    error_message = "Without private_ip_address the allocation should be Dynamic and the address left out of the body."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.private_ip_address == null && azapi_resource.this.replace_triggers_external_values.subnet_id == var.subnet_id
    error_message = "A new subnet or address should replace the endpoint."
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && length(coalesce(azapi_resource.this.tags, {})) == 0
    error_message = "retry, timeouts and tags should be unset by default."
  }
  assert {
    condition     = output.private_ip_address == "10.0.0.4"
    error_message = "private_ip_address should come from the address Azure reports."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && length(output.lock_dependency) == 64
    error_message = "resource_id, name and lock_dependency should come from the endpoint."
  }
}

run "static_address" {
  command = apply

  variables {
    private_ip_address = "10.0.0.10"
    tags               = { environment = "test" }
  }

  assert {
    condition     = azapi_resource.this.body.properties.ipConfigurations[0].privateIpAllocationMethod == "Static" && azapi_resource.this.body.properties.ipConfigurations[0].privateIpAddress == "10.0.0.10"
    error_message = "private_ip_address should be sent with the Static allocation method."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.private_ip_address == "10.0.0.10"
    error_message = "A new address should replace the endpoint."
  }
  assert {
    condition     = azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "tags should be set on the endpoint."
  }
}

run "overrides" {
  command = apply

  variables {
    resource_types      = { network_dns_resolvers_inbound_endpoints = "Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01" }
    ignore_body_changes = { network_dns_resolvers_inbound_endpoints = ["properties.ipConfigurations"] }
    retry               = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts            = { create = "30m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01"
    error_message = "resource_types should override the API version."
  }
  assert {
    condition     = azapi_resource.this.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && azapi_resource.this.timeouts.create == "30m"
    error_message = "retry and timeouts should be passed to the resource."
  }
}

run "invalid_private_ip_address" {
  command = plan

  variables {
    private_ip_address = "10.0.0.300"
  }

  expect_failures = [var.private_ip_address]
}

run "ipv6_private_ip_address" {
  command = plan

  variables {
    private_ip_address = "2001:db8::4"
  }

  expect_failures = [var.private_ip_address]
}

run "invalid_name" {
  command = plan

  variables {
    name = "in_"
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
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.subnet_id]
}
