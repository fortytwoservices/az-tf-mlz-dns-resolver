# Reads resources of one type straight from Azure; fails if one is missing. Called by the root's and
# every submodule's integration tests.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "ids" {
  type = map(string)
}

variable "type" {
  type = string
}

data "azapi_resource" "this" {
  for_each = var.ids

  type                   = var.type
  resource_id            = each.value
  response_export_values = ["properties", "tags"]
}

output "properties" {
  value = { for key, resource in data.azapi_resource.this : key => resource.output.properties }
}

output "tags" {
  value = { for key, resource in data.azapi_resource.this : key => try(resource.output.tags, null) }
}
