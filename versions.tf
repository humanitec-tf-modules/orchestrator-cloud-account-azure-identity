terraform {
  required_version = ">= 1.11.0"

  required_providers {
    humanitec = {
      source  = "humanitec/humanitec"
      version = "~> 1.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.78"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
