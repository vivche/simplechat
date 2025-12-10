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

data "azurerm_container_registry" "acrregistry" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

data "azurerm_log_analytics_workspace" "law" {
  name                = var.param_log_analytics_name
  resource_group_name = var.param_resource_group_name
}

data "azurerm_cosmosdb_account" "cosmos" {
  name                = var.param_cosmos_account_name
  resource_group_name = var.param_resource_group_name
}

data "azurerm_search_service" "search" {
  name                = var.param_search_service_name
  resource_group_name = var.param_resource_group_name
}

data "azurerm_cognitive_account" "docintel" {
  name                = var.param_docintel_account_name
  resource_group_name = var.param_resource_group_name
}

data "azurerm_redis_cache" "redis" {
  name                = var.param_redis_cache_name
  resource_group_name = var.param_resource_group_name
}

data "azurerm_application_insights" "ai" {
  name                = var.param_appinsights_name
  resource_group_name = var.param_resource_group_name
}

data "azuread_application" "app_registration" {
  client_id = var.param_app_registration_client_id
}

data "azurerm_user_assigned_identity" "id" {
  name                = var.param_user_assigned_identity_name
  resource_group_name = var.param_resource_group_name
}

# Locals
locals {
  param_registry_server = "${var.acr_name}.azurecr.io"
  param_base_name       = "${var.param_base_name}-${var.param_environment}"
  
  cosmos_db_url_template = var.global_which_azure_platform == "AzureUSGovernment" ? "https://%s.documents.azure.us:443/" : "https://%s.documents.azure.com:443/"
  openai_url_template    = var.global_which_azure_platform == "AzureUSGovernment" ? "https://%s.openai.azure.us/" : "https://%s.openai.azure.com/"
  
  common_tags = {
    Environment = var.param_environment
    Owner       = var.param_resource_owner_id
    Project     = "SimpleChat-ContainerApp"
  }
}
