####################################################################################################
# File:         main.tf
# Description:  Terraform configuration for deploying Simple Chat to Azure Container Apps
# Author:       Microsoft Federal
# Created:      2025-Dec-09
# Version:      1.0.0
####################################################################################################

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.4.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.29, < 5.0.0"
    }
  }
}

# Configure the AzureRM Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  storage_use_azuread = true
  environment = var.global_which_azure_platform == "AzureUSGovernment" ? "usgovernment" : (var.global_which_azure_platform == "AzureCloud" ? "public" : null)
  tenant_id   = var.param_tenant_id
  subscription_id = var.param_subscription_id
}

# Configure the AzureAD Provider
provider "azuread" {
  environment = var.global_which_azure_platform == "AzureUSGovernment" ? "usgovernment" : (var.global_which_azure_platform == "AzureCloud" ? "public" : null)
  tenant_id = var.param_tenant_id
}

# Data sources for existing resources
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.param_resource_group_name
}

# ACR and OpenAI are pre-existing, created via PowerShell
data "azurerm_container_registry" "acrregistry" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

data "azurerm_cognitive_account" "openai" {
  name                = var.param_existing_azure_openai_resource_name
  resource_group_name = var.param_existing_azure_openai_resource_group_name
}

# User data source for app registration ownership
data "azuread_user" "application_owner" {
  user_principal_name = var.param_resource_owner_email_id
}

# Note: Infrastructure resources (Cosmos, Search, Redis, etc.) are created in infrastructure.tf
# They can be referenced directly in containerapp.tf as resource references

# Locals
locals {
  param_registry_server = "${var.acr_name}.azurecr.io"
  param_base_name       = "${var.param_base_name}-${var.param_environment}"
  app_registration_name = "${var.param_base_name}-${var.param_environment}-ar"
  containerapp_fqdn_suffix = var.global_which_azure_platform == "AzureUSGovernment" ? ".azurecontainerapps.us" : ".azurecontainerapps.io"
  
  cosmos_db_url_template = var.global_which_azure_platform == "AzureUSGovernment" ? "https://%s.documents.azure.us:443/" : "https://%s.documents.azure.com:443/"
  openai_url_template    = var.global_which_azure_platform == "AzureUSGovernment" ? "https://%s.openai.azure.us/" : "https://%s.openai.azure.com/"
  
  common_tags = {
    Environment = var.param_environment
    Owner       = var.param_resource_owner_id
    Project     = "SimpleChat-ContainerApp"
  }
}

####################################################################################################
# Azure AD App Registration (for authentication)
####################################################################################################

resource "azuread_application" "app_registration" {
  display_name = local.app_registration_name
  owners       = [data.azuread_client_config.current.object_id, data.azuread_user.application_owner.object_id]

  web {
    redirect_uris = [
      "https://${local.param_base_name}-containerapp${local.containerapp_fqdn_suffix}/.auth/login/aad/callback",
      "https://${local.param_base_name}-containerapp${local.containerapp_fqdn_suffix}/getAToken",
    ]
    logout_url = "https://${local.param_base_name}-containerapp${local.containerapp_fqdn_suffix}/logout"
    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }

}

####################################################################################################
# App Roles for the Application
####################################################################################################

resource "azuread_application_app_role" "app_registration_admin" {
  application_id       = azuread_application.app_registration.id
  allowed_member_types = ["User"]
  description          = "Allows access to Admin Settings page."
  display_name         = "Admins"
  value                = "Admin"
  role_id              = "e9b4823f-d17a-44f1-9d71-0f2c0ee45656"
}

resource "azuread_application_app_role" "app_registration_user" {
  application_id       = azuread_application.app_registration.id
  allowed_member_types = ["User"]
  description          = "Standard user access to chat features."
  display_name         = "Users"
  value                = "User"
  role_id              = "633746c6-3d03-480f-b273-58ece728be52"
}

resource "azuread_application_app_role" "app_registration_feedbackadmin" {
  application_id       = azuread_application.app_registration.id
  allowed_member_types = ["User"]
  description          = "Allows access to view user feedback admin page."
  display_name         = "Feedback Admin"
  value                = "FeedbackAdmin"
  role_id              = "12e32860-88a8-421e-8a6f-faf08e3efe2e"
}

resource "azuread_application_app_role" "app_registration_safetyviolationadmin" {
  application_id       = azuread_application.app_registration.id
  allowed_member_types = ["User"]
  description          = "Allows access to view content safety violations."
  display_name         = "Safety Violation Admin"
  value                = "SafetyViolationAdmin"
  role_id              = "877166d4-eaa3-4fa6-8d79-e2f325f0e331"
}

resource "azuread_application_app_role" "app_registration_creategroups" {
  application_id       = azuread_application.app_registration.id
  allowed_member_types = ["User"]
  description          = "Allows user to create new groups (if enabled)."
  display_name         = "Create Group"
  value                = "CreateGroups"
  role_id              = "3a614cbb-7f8b-47e1-8e55-5b3c4f71a1c8"
}

resource "azuread_application_app_role" "app_registration_createpublicworkspaces" {
  application_id       = azuread_application.app_registration.id
  allowed_member_types = ["User"]
  description          = "Allows user to create new public workspaces (if enabled)."
  display_name         = "Create Public Workspace"
  value                = "CreatePublicWorkspaces"
  role_id              = "7b5c9d8e-4f2a-11ef-9b3c-0242ac120002"
}

resource "azuread_application_password" "app_registration_secret" {
  application_id = azuread_application.app_registration.id
  rotate_when_changed = {
    rotation = 180
  }
}
