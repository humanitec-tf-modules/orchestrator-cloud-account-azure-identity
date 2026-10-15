variable "humanitec_org_id" {
  type        = string
  description = "Humanitec Organization ID"
  nullable    = false
}
variable "cloud_account_id" {
  type        = string
  description = "ID for the Cloud Account. Must be 2–63 chars, only lowercase letters, digits and single hyphens, no leading/trailing hyphen. If not set, the module generates an ID with a random suffix"
  nullable    = true
  default     = null

  validation {
    # Using a ternary instead of "||" to support Terraform <= 1.11 which does not yet short-circuit logical operators
    condition     = var.cloud_account_id == null ? true : length(var.cloud_account_id) >= 2 && length(var.cloud_account_id) <= 63
    error_message = "cloud_account_id must be between 2 and 63 characters long"
  }

  validation {
    condition     = var.cloud_account_id == null || can(regex("^[a-z0-9](?:-?[a-z0-9]+)+$", var.cloud_account_id))
    error_message = "cloud_account_id must only contain lowercase letters, digits, and single hyphens, and must not start or end with a hyphen"
  }
}
variable "cloud_account_name" {
  type        = string
  description = "Name for the Cloud Account. If not set, will be set to the value of `cloud_account_id`"
  nullable    = true
  default     = null
}
variable "managed_identity_create" {
  type        = bool
  description = "Whether to create the user-assigned managed identity used via the Cloud Account. If `false`, `managed_identity_id` must be the resource ID of an existing managed identity"
  nullable    = false
  default     = true
}
variable "managed_identity_name" {
  type        = string
  description = "The name for the managed identity created by the module. If not set, the module generates a name including the cloud account id. Only used if `managed_identity_create` is `true`"
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create || var.managed_identity_name == null
    error_message = "managed_identity_name must not be set if managed_identity_create is false. Use managed_identity_id to pass in an existing managed identity"
  }
}
variable "managed_identity_resource_group_name" {
  type        = string
  description = "The name of an existing resource group to create the managed identity in. Its location is the default for `managed_identity_location`. Required if `managed_identity_create` is `true`, must not be set otherwise"
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create ? var.managed_identity_resource_group_name != null : var.managed_identity_resource_group_name == null
    error_message = "managed_identity_resource_group_name must be set if managed_identity_create is true, and must not be set otherwise"
  }
}
variable "managed_identity_location" {
  type        = string
  description = "The Azure region to create the managed identity in, e.g. `westeurope`. If not set, the module uses the location of the resource group `managed_identity_resource_group_name`. Only used if `managed_identity_create` is `true`"
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create || var.managed_identity_location == null
    error_message = "managed_identity_location must not be set if managed_identity_create is false"
  }
}
variable "managed_identity_tags" {
  type        = map(string)
  description = "Tags to assign to the managed identity created by the module. Only used if `managed_identity_create` is `true`"
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create || var.managed_identity_tags == null
    error_message = "managed_identity_tags must not be set if managed_identity_create is false"
  }
}
variable "managed_identity_id" {
  type        = string
  description = "The resource ID of an existing user-assigned managed identity used via the Cloud Account. It must be located in the subscription of the `azurerm` provider that is passed in to the module. The module reads the identity to obtain its client ID and tenant ID. Required if `managed_identity_create` is `false`, must not be set otherwise"
  nullable    = true
  default     = null

  validation {
    condition     = var.managed_identity_create ? var.managed_identity_id == null : var.managed_identity_id != null
    error_message = "managed_identity_id must be set if managed_identity_create is false, and must not be set otherwise"
  }

  validation {
    condition     = var.managed_identity_id == null || can(regex(local.managed_identity_id_pattern, var.managed_identity_id))
    error_message = "managed_identity_id must be a managed identity resource ID like /subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/my-identity"
  }
}
variable "federated_identity_credential_create" {
  type        = bool
  description = "Whether to create the federated identity credential trusting the Humanitec OIDC provider on the managed identity. Set to `false` if you manage the credential yourself. Use the `federated_identity_credential` output to configure it"
  nullable    = false
  default     = true
}
variable "federated_identity_credential_name" {
  type        = string
  description = "The name for the federated identity credential created by the module. If not set, the module generates a name including the cloud account id. Only used if `federated_identity_credential_create` is `true`"
  nullable    = true
  default     = null

  validation {
    condition     = var.federated_identity_credential_create || var.federated_identity_credential_name == null
    error_message = "federated_identity_credential_name must not be set if federated_identity_credential_create is false"
  }
}
