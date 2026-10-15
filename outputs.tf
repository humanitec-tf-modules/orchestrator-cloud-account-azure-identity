output "managed_identity_id" {
  value       = local.managed_identity_id
  description = "Resource ID of the managed identity used by the Cloud Account"
}
output "managed_identity_name" {
  value       = local.managed_identity_name
  description = "Name of the managed identity used by the Cloud Account"
}
output "managed_identity_client_id" {
  value       = local.managed_identity_client_id
  description = "Client ID of the managed identity used by the Cloud Account"
}
output "managed_identity_object_id" {
  value       = local.managed_identity_object_id
  description = "Object ID (principal ID) of the managed identity used by the Cloud Account, i.e. the object ID of its service principal in Microsoft Entra ID. Use it as the principal ID to assign Azure roles to the identity"
}
output "azure_tenant_id" {
  value       = local.managed_identity_tenant_id
  description = "ID of the Azure tenant of the managed identity"
}
output "cloud_account_id" {
  value       = humanitec_resource_account.azure_identity.id
  description = "ID of the Orchestrator Cloud Account"
}
output "cloud_account_name" {
  value       = humanitec_resource_account.azure_identity.name
  description = "Name of the Orchestrator Cloud Account"
}
output "federated_identity_credential_id" {
  value       = one(azurerm_federated_identity_credential.humanitec[*].id)
  description = "Resource ID of the federated identity credential created by the module, or `null` if `federated_identity_credential_create` is `false`"
}
output "federated_identity_credential" {
  value       = local.federated_credential
  description = "Issuer, subject, and audience of the federated identity credential allowing the Cloud Account to use the managed identity. If `federated_identity_credential_create` is `false`, configure a credential with these values on the managed identity yourself"
}
