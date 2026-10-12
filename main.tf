resource "random_string" "cloud_account_id_suffix" {
  count   = var.cloud_account_id == null ? 1 : 0
  length  = 8
  upper   = false
  special = false
}

locals {
  cloud_account_type        = "azure-identity"
  cloud_account_id          = var.cloud_account_id != null ? var.cloud_account_id : "azure-identity-${random_string.cloud_account_id_suffix[0].result}"
  cloud_account_name        = var.cloud_account_name != null ? var.cloud_account_name : local.cloud_account_id
  federated_credential_name = var.federated_identity_credential_name != null ? var.federated_identity_credential_name : "humanitec-${local.cloud_account_id}"

  # Attributes of the managed identity, either created by the module or passed in
  managed_identity_id        = var.managed_identity_create ? azurerm_user_assigned_identity.cloud_account_identity[0].id : var.managed_identity_id
  managed_identity_name      = var.managed_identity_create ? azurerm_user_assigned_identity.cloud_account_identity[0].name : data.azurerm_user_assigned_identity.existing[0].name
  managed_identity_client_id = var.managed_identity_create ? azurerm_user_assigned_identity.cloud_account_identity[0].client_id : data.azurerm_user_assigned_identity.existing[0].client_id
  managed_identity_object_id = var.managed_identity_create ? azurerm_user_assigned_identity.cloud_account_identity[0].principal_id : data.azurerm_user_assigned_identity.existing[0].principal_id
  managed_identity_tenant_id = var.managed_identity_create ? azurerm_user_assigned_identity.cloud_account_identity[0].tenant_id : data.azurerm_user_assigned_identity.existing[0].tenant_id

  # Federated identity credential settings for the Humanitec OIDC provider
  federated_credential = {
    issuer   = "https://idtoken.humanitec.io"
    subject  = "${var.humanitec_org_id}/${local.cloud_account_id}"
    audience = "api://AzureADTokenExchange"
  }

  # Resource group and name of an existing managed identity, parsed from its resource ID
  existing_identity_id_parts = var.managed_identity_id != null ? regex("(?i)^/subscriptions/[^/]+/resourceGroups/(?P<resource_group_name>[^/]+)/providers/Microsoft\\.ManagedIdentity/userAssignedIdentities/(?P<name>[^/]+)$", var.managed_identity_id) : null
}

# Managed identity used via the Cloud Account. Create only if requested
resource "azurerm_user_assigned_identity" "cloud_account_identity" {
  count               = var.managed_identity_create ? 1 : 0
  name                = var.managed_identity_name != null ? var.managed_identity_name : "humanitec-${local.cloud_account_id}"
  resource_group_name = var.managed_identity_resource_group_name
  location            = var.managed_identity_location != null ? var.managed_identity_location : data.azurerm_resource_group.managed_identity[0].location
  tags                = var.managed_identity_tags
}

# Resource group of the new managed identity. Read only if its location is needed as the default
data "azurerm_resource_group" "managed_identity" {
  count = var.managed_identity_create && var.managed_identity_location == null ? 1 : 0
  name  = var.managed_identity_resource_group_name
}

# Existing managed identity. Read only if the module does not create the identity
data "azurerm_user_assigned_identity" "existing" {
  count               = var.managed_identity_create ? 0 : 1
  name                = local.existing_identity_id_parts.name
  resource_group_name = local.existing_identity_id_parts.resource_group_name
}

# Federated identity credential trusting the Humanitec OIDC provider. Create only if requested
resource "azurerm_federated_identity_credential" "humanitec" {
  count                     = var.federated_identity_credential_create ? 1 : 0
  name                      = local.federated_credential_name
  user_assigned_identity_id = local.managed_identity_id
  issuer                    = local.federated_credential.issuer
  subject                   = local.federated_credential.subject
  audience                  = [local.federated_credential.audience]
}

# Orchestrator Cloud Account
resource "humanitec_resource_account" "azure_identity" {
  id   = local.cloud_account_id
  name = local.cloud_account_name
  type = local.cloud_account_type
  credentials = jsonencode({
    azure_identity_tenant_id = local.managed_identity_tenant_id
    azure_identity_client_id = local.managed_identity_client_id
  })

  # The Cloud Account is only usable once the federated identity credential exists
  depends_on = [azurerm_federated_identity_credential.humanitec]
}
