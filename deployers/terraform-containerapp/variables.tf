####################################################################################################
# Variables for Container App deployment
####################################################################################################

variable "global_which_azure_platform" {
  description = "Set to 'AzureUSGovernment' for Azure Government, 'AzureCloud' for Azure Commercial."
  type        = string
  default     = "AzureCloud"
}

variable "param_subscription_id" {
  description = "Your Azure Subscription ID."
  type        = string
}

variable "param_tenant_id" {
  description = "Your Azure AD Tenant ID."
  type        = string
}

variable "param_location" {
  description = "Azure region for deployments."
  type        = string
}

variable "param_resource_owner_id" {
  description = "Used for tagging resources."
  type        = string
}

variable "param_environment" {
  description = "Environment name (dev, test, prod)."
  type        = string
}

variable "param_base_name" {
  description = "Base name for resources."
  type        = string
}

# Existing resource references
variable "param_resource_group_name" {
  description = "Existing resource group name."
  type        = string
}

variable "param_log_analytics_name" {
  description = "Existing Log Analytics workspace name."
  type        = string
}

variable "param_cosmos_account_name" {
  description = "Existing Cosmos DB account name."
  type        = string
}

variable "param_search_service_name" {
  description = "Existing Azure Search service name."
  type        = string
}

variable "param_docintel_account_name" {
  description = "Existing Document Intelligence account name."
  type        = string
}

variable "param_redis_cache_name" {
  description = "Existing Redis Cache name."
  type        = string
}

variable "param_appinsights_name" {
  description = "Existing Application Insights name."
  type        = string
}

variable "param_app_registration_client_id" {
  description = "Existing Azure AD App Registration Client ID."
  type        = string
}

variable "param_user_assigned_identity_name" {
  description = "Existing user-assigned managed identity name."
  type        = string
}

variable "param_app_registration_secret" {
  description = "Azure AD App Registration secret value."
  type        = string
  sensitive   = true
}

# ACR configuration
variable "acr_name" {
  description = "Azure Container Registry name."
  type        = string
}

variable "acr_resource_group_name" {
  description = "Resource group containing the ACR."
  type        = string
}

variable "image_name" {
  description = "Container image name with tag."
  type        = string
}

# OpenAI configuration
variable "param_use_existing_openai_instance" {
  description = "Whether to use existing OpenAI instance."
  type        = bool
  default     = true
}

variable "param_existing_azure_openai_resource_group_name" {
  description = "Resource group of existing OpenAI resource."
  type        = string
  default     = ""
}

variable "param_existing_azure_openai_resource_name" {
  description = "Name of existing OpenAI resource."
  type        = string
  default     = ""
}

variable "param_openai_embedding_url" {
  description = "OpenAI embedding endpoint URL."
  type        = string
  default     = ""
}

variable "param_openai_image_gen_url" {
  description = "OpenAI image generation endpoint URL."
  type        = string
  default     = ""
}
