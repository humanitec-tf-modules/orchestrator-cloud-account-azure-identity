# All providers are mocked so runs can use "command = apply" without real credentials.
# This makes values only known after apply (like the random suffix or the client ID
# of a new managed identity) available to assertions.

mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      location = "germanywestcentral"
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/humanitec-azure-identity-abcd1234"
      client_id    = "11111111-1111-1111-1111-111111111111"
      principal_id = "22222222-2222-2222-2222-222222222222"
      tenant_id    = "33333333-3333-3333-3333-333333333333"
    }
  }
}

mock_provider "humanitec" {}

mock_provider "random" {
  mock_resource "random_string" {
    defaults = {
      result = "abcd1234"
    }
  }
}

run "test_all_default" {
  command = apply

  variables {
    humanitec_org_id                     = "my-org"
    managed_identity_resource_group_name = "my-rg"
  }

  assert {
    condition     = humanitec_resource_account.azure_identity.id == "azure-identity-abcd1234"
    error_message = "The Cloud Account ID must default to 'azure-identity-' plus a random suffix"
  }

  assert {
    condition     = humanitec_resource_account.azure_identity.name == humanitec_resource_account.azure_identity.id
    error_message = "The Cloud Account name must default to the Cloud Account ID"
  }

  assert {
    condition     = humanitec_resource_account.azure_identity.type == "azure-identity"
    error_message = "The Cloud Account type must be 'azure-identity'"
  }

  assert {
    condition     = azurerm_user_assigned_identity.cloud_account_identity[0].name == "humanitec-azure-identity-abcd1234"
    error_message = "The managed identity name must default to 'humanitec-' plus the Cloud Account ID"
  }

  assert {
    condition     = azurerm_user_assigned_identity.cloud_account_identity[0].location == "germanywestcentral"
    error_message = "The managed identity location must default to the location of the resource group"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].name == "humanitec-azure-identity-abcd1234"
    error_message = "The federated identity credential name must default to 'humanitec-' plus the Cloud Account ID"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].subject == "my-org/azure-identity-abcd1234"
    error_message = "The federated identity credential subject must use the generated Cloud Account ID"
  }

  assert {
    condition     = azurerm_federated_identity_credential.humanitec[0].user_assigned_identity_id == azurerm_user_assigned_identity.cloud_account_identity[0].id
    error_message = "The federated identity credential must be created on the new managed identity"
  }

  assert {
    condition     = jsondecode(humanitec_resource_account.azure_identity.credentials) == { azure_identity_client_id = "11111111-1111-1111-1111-111111111111", azure_identity_tenant_id = "33333333-3333-3333-3333-333333333333" }
    error_message = "The Cloud Account credentials must contain the client and tenant ID of the new managed identity"
  }

  assert {
    condition     = output.managed_identity_object_id == "22222222-2222-2222-2222-222222222222"
    error_message = "The managed_identity_object_id output must be the object ID of the new managed identity"
  }

  assert {
    condition     = output.federated_identity_credential_id == azurerm_federated_identity_credential.humanitec[0].id
    error_message = "The federated_identity_credential_id output must be the ID of the new federated identity credential"
  }
}
