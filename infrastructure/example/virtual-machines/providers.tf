terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.0"
    }
  }

  # Backend configuration is supplied at terraform init time via -backend-config.
  # See env/<environment>/<environment>.tfbackend for environment-specific values.
  backend "azurerm" {
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "none"
  # subscription_id is supplied via ARM_SUBSCRIPTION_ID, resolved from
  # the SUBSCRIPTION_MAP repository Actions variable by the CI/CD workflow at runtime.
}

provider "azapi" {}

