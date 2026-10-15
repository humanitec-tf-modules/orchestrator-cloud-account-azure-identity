# See https://developer.hashicorp.com/terraform/language/tests for more on how to write tests.
# See https://developer.hashicorp.com/terraform/language/tests/mocking for information on mocking providers.

# Mocked so the tests need no Azure credentials. The data source returns fixed values for an existing identity
mock_provider "azurerm" {
  # OpenTofu generates mock values for computed attributes at plan time, but azurerm validates
  # the identity ID referenced by the federated identity credential, so it must be well-formed
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-identity"
    }
  }

  mock_data "azurerm_resource_group" {
    defaults = {
      location = "germanywestcentral"
    }
  }

  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "azurerm_user_assigned_identity" {
    defaults = {
      client_id    = "11111111-1111-1111-1111-111111111111"
      principal_id = "22222222-2222-2222-2222-222222222222"
      tenant_id    = "33333333-3333-3333-3333-333333333333"
    }
  }
}

# Mocked so the tests need no Humanitec API token
mock_provider "humanitec" {}

variables {
  humanitec_org_id = "my-org"
}

run "test_federated_identity_credential" {
  command = plan

  variables {
    cloud_account_id                     = "my-cloud-account"
    managed_identity_resource_group_name = "my-rg"
    managed_identity_location            = "westeurope"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].issuer == "https://idtoken.humanitec.io"
    error_message = "The federated identity credential must trust the Humanitec OIDC issuer"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].subject == "my-org/my-cloud-account"
    error_message = "The federated identity credential subject must be '<humanitec_org_id>/<cloud_account_id>'"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].audience == tolist(["api://AzureADTokenExchange"])
    error_message = "The federated identity credential audience must be 'api://AzureADTokenExchange'"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].name == "humanitec-my-cloud-account"
    error_message = "The federated identity credential name must default to 'humanitec-' plus the Cloud Account ID"
  }

  assert {
    condition     = azurerm_user_assigned_identity.cloud_account_identity[0].name == "humanitec-my-cloud-account"
    error_message = "The managed identity name must default to 'humanitec-' plus the Cloud Account ID"
  }

  assert {
    condition     = azurerm_user_assigned_identity.cloud_account_identity[0].resource_group_name == var.managed_identity_resource_group_name && azurerm_user_assigned_identity.cloud_account_identity[0].location == var.managed_identity_location
    error_message = "The managed identity must be created in managed_identity_resource_group_name and managed_identity_location"
  }

  assert {
    condition     = length(data.azurerm_resource_group.managed_identity) == 0
    error_message = "The module must not read the resource group if managed_identity_location is set"
  }

  assert {
    condition     = output.federated_identity_credential == { issuer = "https://idtoken.humanitec.io", subject = "my-org/my-cloud-account", audience = "api://AzureADTokenExchange" }
    error_message = "The federated_identity_credential output must contain issuer, subject, and audience"
  }
}

run "test_default_location" {
  command = plan

  variables {
    managed_identity_resource_group_name = "my-rg"
  }

  assert {
    condition     = data.azurerm_resource_group.managed_identity[0].name == var.managed_identity_resource_group_name
    error_message = "The module must read the resource group managed_identity_resource_group_name if managed_identity_location is not set"
  }

  assert {
    condition     = azurerm_user_assigned_identity.cloud_account_identity[0].location == "germanywestcentral"
    error_message = "The managed identity location must default to the location of the resource group"
  }
}

run "test_custom_names" {
  command = plan

  variables {
    cloud_account_id                     = "my-cloud-account"
    cloud_account_name                   = "My Cloud Account"
    managed_identity_resource_group_name = "my-rg"
    managed_identity_location            = "westeurope"
    managed_identity_name                = "my-identity"
    managed_identity_tags                = { env = "test" }
    federated_identity_credential_name   = "my-credential"
  }

  assert {
    condition     = humanitec_resource_account.azure_identity.name == var.cloud_account_name
    error_message = "The Cloud Account name must equal the cloud_account_name variable"
  }

  assert {
    condition     = azurerm_user_assigned_identity.cloud_account_identity[0].name == var.managed_identity_name
    error_message = "The managed identity name must equal the managed_identity_name variable"
  }

  assert {
    condition     = azurerm_user_assigned_identity.cloud_account_identity[0].tags["env"] == "test"
    error_message = "The managed identity tags must equal the managed_identity_tags variable"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].name == var.federated_identity_credential_name
    error_message = "The federated identity credential name must equal the federated_identity_credential_name variable"
  }
}

run "test_existing_managed_identity" {
  command = plan

  variables {
    cloud_account_id        = "my-cloud-account"
    managed_identity_create = false
    managed_identity_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-existing-identity"
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.cloud_account_identity) == 0
    error_message = "The module must not create a managed identity if managed_identity_create is false"
  }

  assert {
    condition     = data.azurerm_user_assigned_identity.existing[0].name == "my-existing-identity" && data.azurerm_user_assigned_identity.existing[0].resource_group_name == "my-rg"
    error_message = "The module must read the existing managed identity using the name and resource group from managed_identity_id"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].user_assigned_identity_id == var.managed_identity_id
    error_message = "The federated identity credential must be created on the existing managed identity"
  }

  assert {
    condition     = jsondecode(humanitec_resource_account.azure_identity.credentials) == { azure_identity_client_id = "11111111-1111-1111-1111-111111111111", azure_identity_tenant_id = "33333333-3333-3333-3333-333333333333" }
    error_message = "The Cloud Account credentials must contain the client and tenant ID of the existing managed identity"
  }

  assert {
    condition     = output.managed_identity_id == var.managed_identity_id
    error_message = "The managed_identity_id output must equal the managed_identity_id variable"
  }

  assert {
    condition     = output.managed_identity_name == "my-existing-identity"
    error_message = "The managed_identity_name output must be the name of the existing managed identity"
  }

  assert {
    condition     = output.managed_identity_object_id == "22222222-2222-2222-2222-222222222222"
    error_message = "The managed_identity_object_id output must be the object ID of the existing managed identity"
  }

  assert {
    condition     = output.azure_tenant_id == "33333333-3333-3333-3333-333333333333"
    error_message = "The azure_tenant_id output must be the tenant ID of the existing managed identity"
  }
}

run "test_no_federated_identity_credential" {
  command = plan

  variables {
    cloud_account_id                     = "my-cloud-account"
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-existing-identity"
    federated_identity_credential_create = false
  }

  assert {
    condition     = length(azurerm_federated_identity_credential.humanitec) == 0
    error_message = "The module must not create a federated identity credential if federated_identity_credential_create is false"
  }

  assert {
    condition     = output.federated_identity_credential_id == null
    error_message = "The federated_identity_credential_id output must be null if federated_identity_credential_create is false"
  }

  assert {
    condition     = output.federated_identity_credential.subject == "my-org/my-cloud-account"
    error_message = "The federated_identity_credential output must be available if federated_identity_credential_create is false"
  }
}

run "test_new_managed_identity_requires_resource_group" {
  command = plan

  expect_failures = [
    var.managed_identity_resource_group_name,
  ]
}

run "test_existing_managed_identity_requires_id" {
  command = plan

  variables {
    managed_identity_create = false
  }

  expect_failures = [
    var.managed_identity_id,
  ]
}

run "test_existing_managed_identity_rejects_new_identity_settings" {
  command = plan

  variables {
    managed_identity_create              = false
    managed_identity_id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-existing-identity"
    managed_identity_name                = "my-existing-identity"
    managed_identity_resource_group_name = "my-rg"
    managed_identity_location            = "westeurope"
    managed_identity_tags                = { env = "test" }
  }

  expect_failures = [
    var.managed_identity_name,
    var.managed_identity_resource_group_name,
    var.managed_identity_location,
    var.managed_identity_tags,
  ]
}

run "test_new_managed_identity_rejects_id" {
  command = plan

  variables {
    managed_identity_resource_group_name = "my-rg"
    managed_identity_location            = "westeurope"
    managed_identity_id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-existing-identity"
  }

  expect_failures = [
    var.managed_identity_id,
  ]
}

run "test_existing_managed_identity_in_other_subscription" {
  command = plan

  variables {
    managed_identity_create = false
    managed_identity_id     = "/subscriptions/99999999-9999-9999-9999-999999999999/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-existing-identity"
  }

  expect_failures = [
    data.azurerm_user_assigned_identity.existing,
  ]
}

run "test_invalid_managed_identity_id" {
  command = plan

  variables {
    managed_identity_create = false
    managed_identity_id     = "my-existing-identity"
  }

  expect_failures = [
    var.managed_identity_id,
  ]
}

run "test_no_federated_identity_credential_rejects_name" {
  command = plan

  variables {
    managed_identity_resource_group_name = "my-rg"
    managed_identity_location            = "westeurope"
    federated_identity_credential_create = false
    federated_identity_credential_name   = "my-credential"
  }

  expect_failures = [
    var.federated_identity_credential_name,
  ]
}

run "test_cloud_account_id_valid_min_length" {
  command = plan

  variables {
    cloud_account_id                     = "a1"
    managed_identity_resource_group_name = "my-rg"
    managed_identity_location            = "westeurope"
  }

  assert {
    condition     = humanitec_resource_account.azure_identity.id == "a1"
    error_message = "A 2 character cloud_account_id must be accepted"
  }
}

run "test_cloud_account_id_valid_max_length" {
  command = plan

  variables {
    # 63 characters
    cloud_account_id                     = "a-0123456789-0123456789-0123456789-0123456789-0123456789-012345"
    managed_identity_resource_group_name = "my-rg"
    managed_identity_location            = "westeurope"
  }

  assert {
    condition     = humanitec_resource_account.azure_identity.id == var.cloud_account_id
    error_message = "A 63 character cloud_account_id with single hyphens must be accepted"
  }
}

run "test_cloud_account_id_too_short" {
  command = plan

  variables {
    cloud_account_id                     = "a"
    managed_identity_resource_group_name = "my-rg"
  }

  expect_failures = [
    var.cloud_account_id,
  ]
}

run "test_cloud_account_id_too_long" {
  command = plan

  variables {
    # 64 characters
    cloud_account_id                     = "a-0123456789-0123456789-0123456789-0123456789-0123456789-0123456"
    managed_identity_resource_group_name = "my-rg"
  }

  expect_failures = [
    var.cloud_account_id,
  ]
}

run "test_cloud_account_id_rejects_uppercase" {
  command = plan

  variables {
    cloud_account_id                     = "My-cloud-account"
    managed_identity_resource_group_name = "my-rg"
  }

  expect_failures = [
    var.cloud_account_id,
  ]
}

run "test_cloud_account_id_rejects_invalid_characters" {
  command = plan

  variables {
    cloud_account_id                     = "my_cloud.account"
    managed_identity_resource_group_name = "my-rg"
  }

  expect_failures = [
    var.cloud_account_id,
  ]
}

run "test_cloud_account_id_rejects_leading_hyphen" {
  command = plan

  variables {
    cloud_account_id                     = "-my-cloud-account"
    managed_identity_resource_group_name = "my-rg"
  }

  expect_failures = [
    var.cloud_account_id,
  ]
}

run "test_cloud_account_id_rejects_trailing_hyphen" {
  command = plan

  variables {
    cloud_account_id                     = "my-cloud-account-"
    managed_identity_resource_group_name = "my-rg"
  }

  expect_failures = [
    var.cloud_account_id,
  ]
}

run "test_cloud_account_id_rejects_consecutive_hyphens" {
  command = plan

  variables {
    cloud_account_id                     = "my--cloud-account"
    managed_identity_resource_group_name = "my-rg"
  }

  expect_failures = [
    var.cloud_account_id,
  ]
}
