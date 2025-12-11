####################################################################################################
# File:         infrastructure.tf
# Description:  Creates base infrastructure resources for SimpleChat Container App
#               This should mirror the resources in ../terraform/main.tf but for Container Apps
# Author:       Microsoft Federal
# Created:      2025-Dec-10
####################################################################################################

# Storage Account (for document storage, enhanced citations)
resource "azurerm_storage_account" "sa" {
  name                     = replace("${local.param_base_name}sa", "-", "")  # Remove hyphens for storage account
  location                 = data.azurerm_resource_group.rg.location
  resource_group_name      = data.azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  
  # Enable Azure AD authentication for storage
  shared_access_key_enabled = true

  tags = local.common_tags
}

# User-Assigned Managed Identity
resource "azurerm_user_assigned_identity" "id" {
  name                = "${local.param_base_name}-id"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  tags = local.common_tags
}

# Cosmos DB Account
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "${local.param_base_name}-cosmos"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = data.azurerm_resource_group.rg.location
    failover_priority = 0
  }

  tags = local.common_tags
}

# Azure AI Search Service
resource "azurerm_search_service" "search" {
  name                = "${local.param_base_name}-search"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "basic"
  replica_count       = 1
  partition_count     = 1

  tags = local.common_tags
}

# Document Intelligence (Form Recognizer)
resource "azurerm_cognitive_account" "docintel" {
  name                = "${local.param_base_name}-docintel"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  kind                = "FormRecognizer"
  sku_name            = "S0"

  tags = local.common_tags
}

# Redis Cache
resource "azurerm_redis_cache" "redis" {
  name                = "${local.param_base_name}-redis"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  minimum_tls_version = "1.2"

  tags = local.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${local.param_base_name}-law"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "ai" {
  name                = "${local.param_base_name}-ai"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id

  tags = local.common_tags
}

# Outputs for infrastructure resources
output "managed_identity_id" {
  value       = azurerm_user_assigned_identity.id.id
  description = "The ID of the User-Assigned Managed Identity"
}

output "managed_identity_principal_id" {
  value       = azurerm_user_assigned_identity.id.principal_id
  description = "The Principal ID of the Managed Identity for RBAC assignments"
}

output "managed_identity_client_id" {
  value       = azurerm_user_assigned_identity.id.client_id
  description = "The Client ID of the Managed Identity"
}

output "cosmos_endpoint" {
  value       = azurerm_cosmosdb_account.cosmos.endpoint
  description = "Cosmos DB endpoint URL"
}

output "cosmos_name" {
  value       = azurerm_cosmosdb_account.cosmos.name
  description = "Cosmos DB account name"
}

output "search_service_name" {
  value       = azurerm_search_service.search.name
  description = "Azure AI Search service name"
}

output "docintel_endpoint" {
  value       = azurerm_cognitive_account.docintel.endpoint
  description = "Document Intelligence endpoint"
}

output "redis_hostname" {
  value       = azurerm_redis_cache.redis.hostname
  description = "Redis Cache hostname"
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.law.id
  description = "Log Analytics Workspace ID"
}

output "appinsights_instrumentation_key" {
  value       = azurerm_application_insights.ai.instrumentation_key
  description = "Application Insights instrumentation key"
  sensitive   = true
}

output "appinsights_connection_string" {
  value       = azurerm_application_insights.ai.connection_string
  description = "Application Insights connection string"
  sensitive   = true
}
