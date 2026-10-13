> [!NOTE]
> 🚧 The content of this repository is currently being curated. Please do not use before the first release has been cut.

# Cloud Accounts of type Azure workload identity federation

This repository contains a OpenTofu/Terraform module for managing Cloud Accounts of type [Azure workload identity federation](https://developer.humanitec.com/platform-orchestrator/docs/platform-orchestrator/security/cloud-accounts/azure/#azure-workload-identity-federation) in the [Humanitec Platform Orchestrator](https://developer.humanitec.com/platform-orchestrator/).

## Usage

The module always creates the Orchestrator Cloud Account. It provides flexibility as to which Azure objects to create or to pass in if you prefer to manage them outside of the module.

The Cloud Account uses a [user-assigned managed identity](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview) carrying a [federated identity credential](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation) that trusts the [Humanitec OIDC provider](https://developer.humanitec.com/platform-orchestrator/docs/platform-orchestrator/security/oidc-provider/). The module reads the client ID and tenant ID for the Cloud Account credentials from the managed identity.

### Create managed identity and federated identity credential

```hcl
provider "azurerm" {
  features {}
  subscription_id = "00000000-0000-0000-0000-000000000000"
}

module "cloud_account_azure_identity" {
  source = "github.com/humanitec-tf-modules/orchestrator-cloud-account-azure-identity?ref=vX.Y.Z"

  # Recommended: explicitly pass in the provider configurations
  providers = {
    humanitec = humanitec
    azurerm   = azurerm
  }

  humanitec_org_id                     = "my-org"
  cloud_account_id                     = "my-azure-identity-account"
  cloud_account_name                   = "My Azure identity account"
  managed_identity_name                = "humanitec-access-aks-azure-identity"
  managed_identity_resource_group_name = "my-resource-group"
  managed_identity_location            = "westeurope"
}
```

### Create managed identity and federated identity credential, let module generate names

The managed identity is created in the location of the resource group.

```hcl
module "cloud_account_azure_identity" {
  source = "github.com/humanitec-tf-modules/orchestrator-cloud-account-azure-identity?ref=vX.Y.Z"

  providers = {
    humanitec = humanitec
    azurerm   = azurerm
  }

  humanitec_org_id                     = "my-org"
  managed_identity_resource_group_name = "my-resource-group"
}
```

### Bring existing managed identity

The module creates the federated identity credential on the existing managed identity. It reads the identity to obtain its client ID and tenant ID, which requires read access to the identity.

```hcl
module "cloud_account_azure_identity" {
  source = "github.com/humanitec-tf-modules/orchestrator-cloud-account-azure-identity?ref=vX.Y.Z"

  providers = {
    humanitec = humanitec
    azurerm   = azurerm
  }

  humanitec_org_id        = "my-org"
  managed_identity_create = false
  managed_identity_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-resource-group/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-identity"
}
```

A managed identity supports a [limited number](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-considerations#general-federated-identity-credential-considerations) of federated identity credentials. Each Cloud Account using the same managed identity adds one credential.

### Bring existing managed identity and federated identity credential

```hcl
# Configure the federated identity credential on the managed identity yourself
resource "azurerm_federated_identity_credential" "mine" {
  name                      = "my-humanitec-credential"
  user_assigned_identity_id = azurerm_user_assigned_identity.mine.id
  issuer                    = module.cloud_account_azure_identity.federated_identity_credential.issuer
  subject                   = module.cloud_account_azure_identity.federated_identity_credential.subject
  audience                  = [module.cloud_account_azure_identity.federated_identity_credential.audience]
}

module "cloud_account_azure_identity" {
  source = "github.com/humanitec-tf-modules/orchestrator-cloud-account-azure-identity?ref=vX.Y.Z"

  providers = {
    humanitec = humanitec
    azurerm   = azurerm
  }
  
  humanitec_org_id                     = "my-org"
  cloud_account_id                     = "my-azure-identity-account"
  managed_identity_create              = false
  managed_identity_id                  = azurerm_user_assigned_identity.mine.id
  federated_identity_credential_create = false
}
```

The Cloud Account works only once the federated identity credential exists.

### Assign Azure roles to the managed identity

The module does not assign any Azure roles. Grant the managed identity the permissions it needs on the target Azure services using the `managed_identity_object_id` output, e.g.:

```hcl
resource "azurerm_role_assignment" "aks_cluster_user" {
  scope                = azurerm_kubernetes_cluster.my_cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = module.cloud_account_azure_identity.managed_identity_object_id
  principal_type       = "ServicePrincipal"
}
```

For access to an AKS cluster, refer to the [Kubernetes](https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/containerization/kubernetes/#2-configure-aks-cluster-access) page for guidance.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.78 |
| <a name="requirement_humanitec"></a> [humanitec](#requirement\_humanitec) | ~> 1.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_federated_identity_credential.humanitec](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_user_assigned_identity.cloud_account_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [humanitec_resource_account.azure_identity](https://registry.terraform.io/providers/humanitec/humanitec/latest/docs/resources/resource_account) | resource |
| [random_string.cloud_account_id_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [azurerm_resource_group.managed_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_user_assigned_identity.existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloud_account_id"></a> [cloud\_account\_id](#input\_cloud\_account\_id) | ID for the Cloud Account. If not set, the module generates an ID with a random suffix | `string` | `null` | no |
| <a name="input_cloud_account_name"></a> [cloud\_account\_name](#input\_cloud\_account\_name) | Name for the Cloud Account. If not set, will be set to the value of `cloud_account_id` | `string` | `null` | no |
| <a name="input_federated_identity_credential_create"></a> [federated\_identity\_credential\_create](#input\_federated\_identity\_credential\_create) | Whether to create the federated identity credential trusting the Humanitec OIDC provider on the managed identity. Set to `false` if you manage the credential yourself. Use the `federated_identity_credential` output to configure it | `bool` | `true` | no |
| <a name="input_federated_identity_credential_name"></a> [federated\_identity\_credential\_name](#input\_federated\_identity\_credential\_name) | The name for the federated identity credential created by the module. If not set, the module generates a name including the cloud account id. Only used if `federated_identity_credential_create` is `true` | `string` | `null` | no |
| <a name="input_humanitec_org_id"></a> [humanitec\_org\_id](#input\_humanitec\_org\_id) | Humanitec Organization ID | `string` | n/a | yes |
| <a name="input_managed_identity_create"></a> [managed\_identity\_create](#input\_managed\_identity\_create) | Whether to create the user-assigned managed identity used via the Cloud Account. If `false`, `managed_identity_id` must be the resource ID of an existing managed identity | `bool` | `true` | no |
| <a name="input_managed_identity_id"></a> [managed\_identity\_id](#input\_managed\_identity\_id) | The resource ID of an existing user-assigned managed identity used via the Cloud Account. The module reads the identity to obtain its client and tenant ID. Required if `managed_identity_create` is `false`, must not be set otherwise | `string` | `null` | no |
| <a name="input_managed_identity_location"></a> [managed\_identity\_location](#input\_managed\_identity\_location) | The Azure region to create the managed identity in, e.g. `westeurope`. If not set, the module uses the location of the resource group `managed_identity_resource_group_name`. Only used if `managed_identity_create` is `true` | `string` | `null` | no |
| <a name="input_managed_identity_name"></a> [managed\_identity\_name](#input\_managed\_identity\_name) | The name for the managed identity created by the module. If not set, the module generates a name including the cloud account id. Only used if `managed_identity_create` is `true` | `string` | `null` | no |
| <a name="input_managed_identity_resource_group_name"></a> [managed\_identity\_resource\_group\_name](#input\_managed\_identity\_resource\_group\_name) | The name of an existing resource group to create the managed identity in. Its location is the default for `managed_identity_location`. Required if `managed_identity_create` is `true`, must not be set otherwise | `string` | `null` | no |
| <a name="input_managed_identity_tags"></a> [managed\_identity\_tags](#input\_managed\_identity\_tags) | Tags to assign to the managed identity created by the module. Only used if `managed_identity_create` is `true` | `map(string)` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azure_tenant_id"></a> [azure\_tenant\_id](#output\_azure\_tenant\_id) | ID of the Azure tenant of the managed identity |
| <a name="output_cloud_account_id"></a> [cloud\_account\_id](#output\_cloud\_account\_id) | ID of the Orchestrator Cloud Account |
| <a name="output_cloud_account_name"></a> [cloud\_account\_name](#output\_cloud\_account\_name) | Name of the Orchestrator Cloud Account |
| <a name="output_federated_identity_credential"></a> [federated\_identity\_credential](#output\_federated\_identity\_credential) | Issuer, subject, and audience of the federated identity credential allowing the Cloud Account to use the managed identity. If `federated_identity_credential_create` is `false`, configure a credential with these values on the managed identity yourself |
| <a name="output_federated_identity_credential_id"></a> [federated\_identity\_credential\_id](#output\_federated\_identity\_credential\_id) | Resource ID of the federated identity credential created by the module, or `null` if `federated_identity_credential_create` is `false` |
| <a name="output_managed_identity_client_id"></a> [managed\_identity\_client\_id](#output\_managed\_identity\_client\_id) | Client ID of the managed identity used by the Cloud Account |
| <a name="output_managed_identity_id"></a> [managed\_identity\_id](#output\_managed\_identity\_id) | Resource ID of the managed identity used by the Cloud Account |
| <a name="output_managed_identity_name"></a> [managed\_identity\_name](#output\_managed\_identity\_name) | Name of the managed identity used by the Cloud Account |
| <a name="output_managed_identity_object_id"></a> [managed\_identity\_object\_id](#output\_managed\_identity\_object\_id) | Object ID (principal ID) of the managed identity used by the Cloud Account, i.e. the object ID of its service principal in Microsoft Entra ID. Use it as the principal ID to assign Azure roles to the identity |
<!-- END_TF_DOCS -->
