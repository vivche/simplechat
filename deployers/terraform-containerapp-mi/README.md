# SimpleChat - Azure Container Apps Deployment with Managed Identity

This Terraform configuration deploys the SimpleChat application to **Azure Container Apps** using **Managed Identity authentication** for all Azure services, eliminating the need for keys and connection strings.

## 🔐 Authentication Strategy

This deployment uses **Managed Identity** for all Azure service authentication:

| Service | Authentication Method | RBAC Role Required |
|---------|----------------------|-------------------|
| **Azure Container Registry** | User-Assigned MI | AcrPull |
| **Cosmos DB** | User-Assigned MI | Cosmos DB Built-in Data Contributor |
| **Azure AI Search** | User-Assigned MI | Search Index Data Contributor |
| **Document Intelligence** | User-Assigned MI | Cognitive Services User |
| **Redis Cache** | User-Assigned MI | Redis Cache Contributor |
| **Azure OpenAI** | User-Assigned MI | Cognitive Services OpenAI User |

## 📋 Prerequisites

### 1. Infrastructure Resources (Created)
✅ **Resource Group**: `container-mi-rg`  
✅ **Azure Container Registry**: `containermiacrdev.azurecr.io`  
✅ **Azure OpenAI**: `containermi-openai-dev`

### 2. Required Resources (To Create)
You need to provision these resources before deploying the Container App:

- **User-Assigned Managed Identity** (e.g., `containermi-dev-id`)
- **Cosmos DB Account** (e.g., `containermi-dev-cosmos`)
- **Azure AI Search Service** (e.g., `containermi-dev-search`)
- **Document Intelligence** (e.g., `containermi-dev-docintel`)
- **Redis Cache** (e.g., `containermi-dev-redis`)
- **Log Analytics Workspace** (e.g., `containermi-dev-law`)
- **Application Insights** (e.g., `containermi-dev-ai`)
- **Azure AD App Registration** (for authentication)

### 3. Required Permissions
- **Owner** or **Contributor** role on subscription: `e88b99f7-323e-408d-91b9-527f33c00ac7`
- Ability to create role assignments
- Azure AD permissions to read app registrations

## 🚀 Deployment Steps

### Step 1: Login to Azure CLI

```bash
az cloud set --name AzureCloud
az login
az account set --subscription e88b99f7-323e-408d-91b9-527f33c00ac7
```

### Step 2: Build and Push Container Image

From the GitHub Actions or manually:

```bash
# Login to ACR
az acr login --name containermiacrdev

# Build and push image (from repository root)
cd c:\Source\DIA\ContainerMIChat\simplechat
docker build -t containermiacrdev.azurecr.io/simplechat:latest .
docker push containermiacrdev.azurecr.io/simplechat:latest
```

### Step 3: Configure Variables

Edit `container-mi.tfvars` and update these required values:

```hcl
# Update these values:
param_tenant_id                    = "YOUR_TENANT_ID"
param_app_registration_client_id   = "YOUR_APP_REGISTRATION_CLIENT_ID"
param_app_registration_secret      = "YOUR_APP_REGISTRATION_SECRET"

# Update resource names to match your provisioned resources:
param_log_analytics_name          = "containermi-dev-law"
param_cosmos_account_name         = "containermi-dev-cosmos"
param_search_service_name         = "containermi-dev-search"
param_docintel_account_name       = "containermi-dev-docintel"
param_redis_cache_name            = "containermi-dev-redis"
param_appinsights_name            = "containermi-dev-ai"
param_user_assigned_identity_name = "containermi-dev-id"
```

### Step 4: Initialize Terraform

```bash
cd deployers/terraform-containerapp
terraform init
```

### Step 5: Plan Deployment

```bash
terraform plan -var-file="container-mi.tfvars" -out=containerapp.tfplan
```

Review the plan to ensure:
- All RBAC role assignments are being created
- Environment variables use `managed_identity` authentication
- No key/secret environment variables are present

### Step 6: Apply Deployment

```bash
terraform apply containerapp.tfplan
```

### Step 7: Verify Deployment

```bash
# Get the Container App URL
terraform output containerapp_url

# Check Container App status
az containerapp show \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg \
  --query "properties.runningStatus"
```

## 🔍 Post-Deployment Validation

### 1. Check Managed Identity Assignment
```bash
az containerapp identity show \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg
```

### 2. Verify RBAC Role Assignments
```bash
# Get the managed identity principal ID
PRINCIPAL_ID=$(az identity show \
  --name containermi-dev-id \
  --resource-group container-mi-rg \
  --query principalId -o tsv)

# List all role assignments
az role assignment list \
  --assignee $PRINCIPAL_ID \
  --all \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  --output table
```

You should see these roles:
- AcrPull
- Cosmos DB Built-in Data Contributor
- Search Index Data Contributor
- Cognitive Services User (Document Intelligence)
- Redis Cache Contributor
- Cognitive Services OpenAI User

### 3. Test Application Access
```bash
# Get the application URL
APP_URL=$(terraform output -raw containerapp_url)
echo "Application URL: $APP_URL"

# Test health endpoint (if enabled)
curl $APP_URL/health
```

### 4. Check Container Logs
```bash
az containerapp logs show \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg \
  --follow
```

Look for successful authentication messages:
- `"Cosmos DB initialized using Managed Identity"`
- `"Redis enabled using Managed Identity"`
- `"Azure AI Search initialized with Managed Identity"`

## 🛠️ Troubleshooting

### Issue: Container App fails to start

**Check logs:**
```bash
az containerapp logs show \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg \
  --tail 100
```

### Issue: Authentication failures

**Verify role assignments:**
```bash
# Check if managed identity has required roles
az role assignment list \
  --assignee $(az identity show --name containermi-dev-id --resource-group container-mi-rg --query principalId -o tsv) \
  --all
```

**Common causes:**
- Role propagation delay (wait 5-10 minutes after role assignment)
- Incorrect managed identity assignment
- Missing RBAC roles

### Issue: Cosmos DB access denied

**Verify Cosmos DB role:**
```bash
az cosmosdb sql role assignment list \
  --account-name containermi-dev-cosmos \
  --resource-group container-mi-rg
```

**Note:** The "Cosmos DB Built-in Data Contributor" role may take a few minutes to propagate.

### Issue: Redis connection failures

**Check Redis configuration:**
```bash
az redis show \
  --name containermi-dev-redis \
  --resource-group container-mi-rg \
  --query "{hostname:hostName, sslPort:sslPort, enableNonSslPort:enableNonSslPort}"
```

**Verify Redis accepts Managed Identity authentication** (requires Redis 6.0+).

## 🔄 Updating the Deployment

### Update Container Image
```bash
# Build new image
docker build -t containermiacrdev.azurecr.io/simplechat:latest .
docker push containermiacrdev.azurecr.io/simplechat:latest

# Restart Container App to pull new image
az containerapp revision restart \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg
```

### Update Infrastructure
```bash
terraform plan -var-file="container-mi.tfvars"
terraform apply -var-file="container-mi.tfvars"
```

## 🗑️ Cleanup

To destroy all resources:

```bash
terraform destroy -var-file="container-mi.tfvars"
```

**Warning:** This will delete the Container App and all role assignments but will NOT delete the underlying Azure resources (Cosmos DB, Redis, etc.).

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Managed Identity Overview](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [Cosmos DB RBAC](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-rbac)
- [Azure AI Search Security](https://learn.microsoft.com/en-us/azure/search/search-security-rbac)

## 🔐 Security Best Practices

✅ **No secrets in code** - All authentication uses Managed Identity  
✅ **RBAC principle of least privilege** - Specific roles for each service  
✅ **Secrets in variables** - App registration secret in tfvars (not committed to git)  
✅ **Container Registry authentication** - Using managed identity instead of admin credentials

## 📝 Next Steps

1. **Configure Admin Settings** - Access the web UI and configure application settings
2. **Set up AI Search Indexes** - Deploy the required search indexes
3. **Enable Additional Features** - Configure optional services (Video Indexer, Content Safety, etc.)
4. **Monitor Application** - Use Application Insights for monitoring and diagnostics
