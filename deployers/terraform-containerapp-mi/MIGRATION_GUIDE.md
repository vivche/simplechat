# 🔐 Migration from Key-Based to Managed Identity Authentication

## Overview
This document shows the changes made to migrate from key-based authentication to Managed Identity (MI) authentication for Azure Container Apps deployment.

## 📊 Authentication Method Comparison

| Service | Before (Key-Based) | After (Managed Identity) |
|---------|-------------------|-------------------------|
| **Cosmos DB** | `AZURE_COSMOS_KEY` | `AZURE_COSMOS_AUTHENTICATION_TYPE=managed_identity` |
| **Azure Search** | `AZURE_SEARCH_API_KEY` | `AZURE_SEARCH_AUTHENTICATION_TYPE=managed_identity` |
| **Document Intelligence** | `AZURE_DOCUMENT_INTELLIGENCE_API_KEY` | `AZURE_DOCUMENT_INTELLIGENCE_AUTHENTICATION_TYPE=managed_identity` |
| **Redis Cache** | `REDIS_KEY` + `REDIS_AUTH_TYPE=key` | `REDIS_AUTH_TYPE=managed_identity` |
| **OpenAI** | API key (implicit) | Token provider with `DefaultAzureCredential` |
| **Container Registry** | Admin credentials | User-Assigned MI with AcrPull role |

## 🔧 Terraform Changes

### 1. Environment Variables Removed

```hcl
# REMOVED - No longer needed with MI
env {
  name  = "AZURE_COSMOS_KEY"
  value = data.azurerm_cosmosdb_account.cosmos.primary_key
}

env {
  name  = "AZURE_SEARCH_API_KEY"
  value = data.azurerm_search_service.search.primary_key
}

env {
  name  = "AZURE_DOCUMENT_INTELLIGENCE_API_KEY"
  value = data.azurerm_cognitive_account.docintel.primary_access_key
}

env {
  name  = "REDIS_KEY"
  value = data.azurerm_redis_cache.redis.primary_access_key
}
```

### 2. Environment Variables Modified

```hcl
# BEFORE
env {
  name  = "AZURE_COSMOS_AUTHENTICATION_TYPE"
  value = "key"
}

env {
  name  = "REDIS_AUTH_TYPE"
  value = "key"
}

# AFTER
env {
  name  = "AZURE_COSMOS_AUTHENTICATION_TYPE"
  value = "managed_identity"
}

env {
  name  = "REDIS_AUTH_TYPE"
  value = "managed_identity"
}
```

### 3. Environment Variables Added

```hcl
# NEW - Required for MI-based services
env {
  name  = "AZURE_SEARCH_AUTHENTICATION_TYPE"
  value = "managed_identity"
}

env {
  name  = "AZURE_DOCUMENT_INTELLIGENCE_AUTHENTICATION_TYPE"
  value = "managed_identity"
}
```

### 4. RBAC Role Assignments Added

```hcl
# NEW - Cosmos DB access
resource "azurerm_role_assignment" "managed_identity_cosmosdb_contributor" {
  scope                = data.azurerm_cosmosdb_account.cosmos.id
  role_definition_name = "Cosmos DB Built-in Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.id.principal_id
}

# NEW - Azure Search access
resource "azurerm_role_assignment" "managed_identity_search_contributor" {
  scope                = data.azurerm_search_service.search.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = data.azurerm_user_assigned_identity.id.principal_id
}

# NEW - Document Intelligence access
resource "azurerm_role_assignment" "managed_identity_docintel_user" {
  scope                = data.azurerm_cognitive_account.docintel.id
  role_definition_name = "Cognitive Services User"
  principal_id         = data.azurerm_user_assigned_identity.id.principal_id
}

# NEW - Redis access
resource "azurerm_role_assignment" "managed_identity_redis_contributor" {
  scope                = data.azurerm_redis_cache.redis.id
  role_definition_name = "Redis Cache Contributor"
  principal_id         = data.azurerm_user_assigned_identity.id.principal_id
}

# NEW - OpenAI access
resource "azurerm_role_assignment" "managed_identity_openai_user" {
  scope                = data.azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = data.azurerm_user_assigned_identity.id.principal_id
}

resource "azurerm_role_assignment" "managed_identity_openai_contributor" {
  scope                = data.azurerm_cognitive_account.openai.id
  role_definition_name = "Cognitive Services User"
  principal_id         = data.azurerm_user_assigned_identity.id.principal_id
}

# EXISTING - ACR access (unchanged)
resource "azurerm_role_assignment" "containerapp_acr_pull" {
  scope                = data.azurerm_container_registry.acrregistry.id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_user_assigned_identity.id.principal_id
}
```

### 5. Data Sources Added

```hcl
# NEW - Reference to Azure OpenAI resource
data "azurerm_cognitive_account" "openai" {
  name                = var.param_existing_azure_openai_resource_name
  resource_group_name = var.param_existing_azure_openai_resource_group_name
}
```

## 🏗️ Application Code Support

The application already supports both authentication methods via conditional logic:

### Cosmos DB ([config.py](../../application/single_app/config.py#L206-L210))
```python
cosmos_authentication_type = os.getenv("AZURE_COSMOS_AUTHENTICATION_TYPE", "key")

if cosmos_authentication_type == "managed_identity":
    cosmos_client = CosmosClient(cosmos_endpoint, credential=DefaultAzureCredential(), consistency_level="Session")
else:
    cosmos_client = CosmosClient(cosmos_endpoint, cosmos_key, consistency_level="Session")
```

### Redis ([app.py](../../application/single_app/app.py#L112-L148))
```python
redis_auth_type = settings.get('redis_auth_type', 'key').strip().lower()

if redis_auth_type == 'managed_identity':
    from azure.identity import DefaultAzureCredential
    credential = DefaultAzureCredential()
    redis_hostname = redis_url.split('.')[0]
    token = credential.get_token(f"https://{redis_hostname}.cacheinfra.windows.net:10225/appid")
    # Use token for authentication
elif redis_auth_type == 'key':
    # Use key for authentication
```

### Azure AI Search ([config.py](../../application/single_app/config.py#L580-L625))
```python
if settings.get("azure_ai_search_authentication_type") == "managed_identity":
    search_client_user = SearchClient(
        endpoint=azure_ai_search_endpoint,
        index_name="simplechat-user-index",
        credential=DefaultAzureCredential()
    )
else:
    search_client_user = SearchClient(
        endpoint=azure_ai_search_endpoint,
        index_name="simplechat-user-index",
        credential=AzureKeyCredential(azure_ai_search_key)
    )
```

### Document Intelligence ([config.py](../../application/single_app/config.py#L540-L555))
```python
if settings.get("azure_document_intelligence_authentication_type") == "managed_identity":
    document_intelligence_client = DocumentIntelligenceClient(
        endpoint=form_recognizer_endpoint,
        credential=DefaultAzureCredential()
    )
else:
    document_intelligence_client = DocumentIntelligenceClient(
        endpoint=form_recognizer_endpoint,
        credential=AzureKeyCredential(form_recognizer_key)
    )
```

## 🔐 Security Benefits

| Aspect | Key-Based | Managed Identity |
|--------|-----------|------------------|
| **Secrets Management** | Keys stored in env vars | No keys needed |
| **Rotation** | Manual key rotation required | Automatic token refresh |
| **Exposure Risk** | Keys can be exposed in logs/config | Tokens are short-lived |
| **Access Control** | Key grants full access | RBAC allows granular permissions |
| **Audit Trail** | Limited | Full Azure AD audit logs |
| **Compliance** | Keys may not meet requirements | Meets enterprise security standards |

## 📋 Migration Checklist

- [x] ✅ Update Terraform to remove key-based env vars
- [x] ✅ Add RBAC role assignments for all services
- [x] ✅ Update authentication type flags to "managed_identity"
- [x] ✅ Add data source for OpenAI resource
- [x] ✅ Create deployment documentation
- [x] ✅ Update version in config.py
- [ ] ⏳ Provision Azure infrastructure resources
- [ ] ⏳ Build and push container image
- [ ] ⏳ Deploy with Terraform
- [ ] ⏳ Verify RBAC roles propagated
- [ ] ⏳ Test application functionality
- [ ] ⏳ Configure admin settings in UI

## 🎯 Key Differences in Deployment

### Key-Based Deployment
```bash
# Required: Get and store keys
COSMOS_KEY=$(az cosmosdb keys list --name ... --query primaryMasterKey -o tsv)
REDIS_KEY=$(az redis list-keys --name ... --query primaryKey -o tsv)
# ... more keys

# Keys passed as environment variables
terraform apply -var="cosmos_key=$COSMOS_KEY" ...
```

### Managed Identity Deployment
```bash
# Required: Ensure managed identity exists
az identity create --name containermi-dev-id ...

# No keys needed - just deploy
terraform apply -var-file="container-mi.tfvars"

# RBAC roles are automatically created by Terraform
```

## ⚡ Performance Impact

| Operation | Key-Based | Managed Identity |
|-----------|-----------|------------------|
| **Initial Auth** | Instant | ~1-2 sec (token acquisition) |
| **Subsequent Calls** | Instant | Instant (token cached) |
| **Token Refresh** | N/A | Automatic, transparent |
| **Failure Recovery** | Manual key rotation | Automatic retry with new token |

## 🔍 Monitoring Differences

### Key-Based
```bash
# Check if keys are valid (limited visibility)
az cosmosdb check-name-availability ...
```

### Managed Identity
```bash
# Check role assignments
az role assignment list --assignee <PRINCIPAL_ID>

# View sign-in logs for managed identity
az monitor activity-log list --caller <PRINCIPAL_ID>

# Check authentication in Application Insights
```

## 📝 Common Issues and Solutions

### Issue: "Authentication failed" on first deployment
**Cause:** RBAC role assignments take 5-10 minutes to propagate  
**Solution:** Wait and retry, or check role assignments with `az role assignment list`

### Issue: Redis connection fails with MI
**Cause:** Redis Cache must support Entra ID authentication  
**Solution:** Ensure Redis is version 6.0+ and Entra ID is enabled

### Issue: Cosmos DB access denied
**Cause:** Wrong RBAC role assigned  
**Solution:** Use "Cosmos DB Built-in Data Contributor" not "Contributor"

## 🎉 Success Indicators

When migration is successful, you should see in logs:

```
✅ Cosmos DB initialized using Managed Identity
✅ Redis enabled using Managed Identity  
✅ Azure AI Search initialized with Managed Identity
✅ Document Intelligence client created with Managed Identity
✅ OpenAI client initialized with token provider
```

## 📚 Additional Resources

- [Azure Managed Identity Best Practices](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/managed-identity-best-practice-recommendations)
- [Cosmos DB RBAC Guide](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-rbac)
- [Azure AI Search Security](https://learn.microsoft.com/en-us/azure/search/search-security-rbac)
- [Container Apps Managed Identity](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity)
