####################################################################################################
# File:         containerapp.tf
# Description:  Terraform configuration for deploying Simple Chat to Azure Container Apps
# Author:       Microsoft Federal
# Created:      2025-Dec-09
# Version:      1.0.0
####################################################################################################

# Container Apps Environment (required hosting infrastructure)
resource "azurerm_container_app_environment" "containerapp_env" {
  name                       = "${local.param_base_name}-containerenv"
  location                   = data.azurerm_resource_group.rg.location
  resource_group_name        = data.azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  tags = local.common_tags
}

# Container App with managed identity
resource "azurerm_container_app" "simplechat" {
  name                         = "${local.param_base_name}-containerapp"
  container_app_environment_id = azurerm_container_app_environment.containerapp_env.id
  resource_group_name          = data.azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned, UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.id.id]
  }

  registry {
    server   = local.param_registry_server
    identity = azurerm_user_assigned_identity.id.id
  }

  template {
    container {
      name   = "simplechat"
      image  = "${local.param_registry_server}/${var.image_name}"
      cpu    = 1.0
      memory = "2Gi"

      env {
        name  = "SECRET_KEY"
        value = azuread_application_password.app_registration_secret.value
      }

      env {
        name  = "CLIENT_ID"
        value = azuread_application.app_registration.client_id
      }

      env {
        name  = "TENANT_ID"
        value = var.param_tenant_id
      }

      env {
        name  = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
        value = var.param_app_registration_secret
      }

      env {
        name  = "AZURE_ENVIRONMENT"
        value = var.global_which_azure_platform == "AzureUSGovernment" ? "usgovernment" : "public"
      }

      env {
        name  = "AZURE_COSMOS_ENDPOINT"
        value = format(local.cosmos_db_url_template, azurerm_cosmosdb_account.cosmos.name)
      }

      env {
        name  = "COSMOS_KEY"
        value = azurerm_cosmosdb_account.cosmos.primary_key
      }

      env {
        name  = "AZURE_COSMOS_AUTHENTICATION_TYPE"
        value = "key"
      }

      env {
        name  = "AZURE_OPENAI_URL"
        value = var.param_use_existing_openai_instance ? format(local.openai_url_template, var.param_existing_azure_openai_resource_name) : ""
      }

      env {
        name  = "AZURE_OPENAI_GPT_ACCOUNT_NAME"
        value = var.param_use_existing_openai_instance ? var.param_existing_azure_openai_resource_name : ""
      }

      env {
        name  = "AZURE_OPENAI_EMBEDDING_ACCOUNT_NAME"
        value = var.param_use_existing_openai_instance ? var.param_existing_azure_openai_resource_name : ""
      }

      env {
        name  = "AZURE_OPENAI_IMAGE_GEN_ACCOUNT_NAME"
        value = var.param_use_existing_openai_instance ? var.param_existing_azure_openai_resource_name : ""
      }

      env {
        name  = "AZURE_OPENAI_EMBEDDING_URL"
        value = var.param_openai_embedding_url
      }

      env {
        name  = "AZURE_OPENAI_IMAGE_GEN_URL"
        value = var.param_openai_image_gen_url
      }

      env {
        name  = "AZURE_OPENAI_SUBSCRIPTION_ID"
        value = var.param_subscription_id
      }

      env {
        name  = "AZURE_OPENAI_RESOURCE_GROUP_NAME"
        value = var.param_use_existing_openai_instance ? var.param_existing_azure_openai_resource_group_name : data.azurerm_resource_group.rg.name
      }

      env {
        name  = "AZURE_SEARCH_SERVICE_NAME"
        value = azurerm_search_service.search.name
      }

      env {
        name  = "SEARCH_API_KEY"
        value = azurerm_search_service.search.primary_key
      }

      env {
        name  = "AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT"
        value = azurerm_cognitive_account.docintel.endpoint
      }

      env {
        name  = "DOCUMENT_INTELLIGENCE_KEY"
        value = azurerm_cognitive_account.docintel.primary_access_key
      }

      env {
        name  = "ENABLE_REDIS_CACHE"
        value = "true"
      }

      env {
        name  = "REDIS_URL"
        value = azurerm_redis_cache.redis.hostname
      }

      env {
        name  = "REDIS_PASSWORD"
        value = azurerm_redis_cache.redis.primary_access_key
      }

      env {
        name  = "REDIS_PORT"
        value = "6380"
      }

      env {
        name  = "REDIS_AUTH_TYPE"
        value = "key"
      }

      env {
        name  = "FLASK_ENV"
        value = "production"
      }

      env {
        name  = "PORT"
        value = "8000"
      }

      env {
        name  = "APPINSIGHTS_INSTRUMENTATIONKEY"
        value = azurerm_application_insights.ai.instrumentation_key
      }

      env {
        name  = "APPLICATIONINSIGHTS_CONNECTION_STRING"
        value = azurerm_application_insights.ai.connection_string
      }
    }

    min_replicas = 1
    max_replicas = 10
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = local.common_tags
}

####################################################################################################
# RBAC Role Assignments for Managed Identity
####################################################################################################

# Role assignment for ACR Pull
resource "azurerm_role_assignment" "containerapp_acr_pull" {
  scope                = data.azurerm_container_registry.acrregistry.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Role assignment for Cosmos DB
resource "azurerm_role_assignment" "cosmos_contributor" {
  scope                = azurerm_cosmosdb_account.cosmos.id
  role_definition_name = "Cosmos DB Built-in Data Contributor"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Role assignment for Azure AI Search
resource "azurerm_role_assignment" "search_contributor" {
  scope                = azurerm_search_service.search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Role assignment for Document Intelligence
resource "azurerm_role_assignment" "docintel_user" {
  scope                = azurerm_cognitive_account.docintel.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Role assignment for Redis Cache
resource "azurerm_role_assignment" "redis_contributor" {
  scope                = azurerm_redis_cache.redis.id
  role_definition_name = "Redis Cache Contributor"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Role assignment for Azure OpenAI
resource "azurerm_role_assignment" "openai_user" {
  scope                = data.azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

# Role assignment for Storage Account
resource "azurerm_role_assignment" "storage_blob_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.id.principal_id
}

####################################################################################################
# Outputs
####################################################################################################

# Output the Container App URL
output "containerapp_fqdn" {
  value       = azurerm_container_app.simplechat.ingress[0].fqdn
  description = "The fully qualified domain name of the Container App"
}

output "containerapp_url" {
  value       = "https://${azurerm_container_app.simplechat.ingress[0].fqdn}"
  description = "The full URL of the Container App"
}
