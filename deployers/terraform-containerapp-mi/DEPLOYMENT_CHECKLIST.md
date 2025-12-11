################################################################################
# Container MI Deployment Checklist
# Updated: December 10, 2025
################################################################################

## ✅ Completed Steps

- [x] Resource Group created: `container-mi-rg`
- [x] Azure Container Registry deployed: `containermiacrdev.azurecr.io`
- [x] Azure OpenAI deployed: `containermi-openai-dev`
- [x] Terraform templates updated for Managed Identity

## 📋 Required Before Deployment

### 1. Provision Infrastructure Resources
Create these Azure resources in `container-mi-rg`:

```bash
# Set variables
RG="container-mi-rg"
LOCATION="eastus2"
BASE_NAME="containermi-dev"

# User-Assigned Managed Identity
az identity create \
  --name ${BASE_NAME}-id \
  --resource-group $RG \
  --location $LOCATION

# Cosmos DB Account
az cosmosdb create \
  --name ${BASE_NAME}-cosmos \
  --resource-group $RG \
  --locations regionName=$LOCATION \
  --default-consistency-level Session \
  --enable-automatic-failover false

# Azure AI Search
az search service create \
  --name ${BASE_NAME}-search \
  --resource-group $RG \
  --location $LOCATION \
  --sku basic

# Document Intelligence
az cognitiveservices account create \
  --name ${BASE_NAME}-docintel \
  --resource-group $RG \
  --location $LOCATION \
  --kind FormRecognizer \
  --sku S0

# Redis Cache
az redis create \
  --name ${BASE_NAME}-redis \
  --resource-group $RG \
  --location $LOCATION \
  --sku Basic \
  --vm-size C0 \
  --enable-non-ssl-port false

# Log Analytics Workspace
az monitor log-analytics workspace create \
  --workspace-name ${BASE_NAME}-law \
  --resource-group $RG \
  --location $LOCATION

# Application Insights
az monitor app-insights component create \
  --app ${BASE_NAME}-ai \
  --resource-group $RG \
  --location $LOCATION \
  --workspace ${BASE_NAME}-law
```

### 2. Create Azure AD App Registration

```bash
# Create app registration
az ad app create \
  --display-name "SimpleChat-ContainerMI" \
  --sign-in-audience AzureADMyOrg

# Note the appId (Client ID) from output
# Create a client secret
az ad app credential reset --id <APP_ID>
# Note the password (Client Secret) from output
```

### 3. Update Terraform Variables

Edit `container-mi.tfvars`:

```hcl
param_tenant_id                    = "<YOUR_TENANT_ID>"
param_app_registration_client_id   = "<APP_ID_FROM_STEP_2>"
param_app_registration_secret      = "<CLIENT_SECRET_FROM_STEP_2>"
```

### 4. Build and Push Docker Image

```bash
# From repository root
cd c:\Source\DIA\ContainerMIChat\simplechat

# Login to ACR
az acr login --name containermiacrdev

# Build and push
docker build -t containermiacrdev.azurecr.io/simplechat:latest .
docker push containermiacrdev.azurecr.io/simplechat:latest
```

## 🚀 Deployment Commands

```bash
cd deployers/terraform-containerapp

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="container-mi.tfvars" -out=containerapp.tfplan

# Apply deployment
terraform apply containerapp.tfplan

# Get application URL
terraform output containerapp_url
```

## 🔍 Post-Deployment Verification

### 1. Check Container App Status
```bash
az containerapp show \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg \
  --query "properties.runningStatus"
```

### 2. Verify RBAC Roles
```bash
PRINCIPAL_ID=$(az identity show \
  --name containermi-dev-id \
  --resource-group container-mi-rg \
  --query principalId -o tsv)

az role assignment list \
  --assignee $PRINCIPAL_ID \
  --all \
  --query "[].{Role:roleDefinitionName, Scope:scope}" \
  --output table
```

Expected roles:
- ✅ AcrPull
- ✅ Cosmos DB Built-in Data Contributor
- ✅ Search Index Data Contributor
- ✅ Cognitive Services User (Document Intelligence)
- ✅ Redis Cache Contributor
- ✅ Cognitive Services OpenAI User

### 3. Check Application Logs
```bash
az containerapp logs show \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg \
  --follow
```

Look for:
- ✅ "Cosmos DB initialized using Managed Identity"
- ✅ "Redis enabled using Managed Identity"
- ✅ "Azure AI Search initialized with Managed Identity"

### 4. Access Application
```bash
# Get URL
APP_URL=$(terraform output -raw containerapp_url)
echo "Application URL: $APP_URL"

# Open in browser
start $APP_URL
```

## 🎯 Configuration in Admin UI

After deployment, configure these in the web UI (Admin Settings):

1. **AI Search Indexes** - Deploy search index schemas
2. **GPT Models** - Configure OpenAI model deployments
3. **Embedding Model** - Set up text-embedding-ada-002
4. **Document Intelligence** - Verify connection (already using MI)
5. **Content Safety** (Optional) - Configure if needed
6. **Storage Account** (Optional) - For enhanced citations using MI

## ⚠️ Important Notes

### Managed Identity Authentication
- ✅ **Cosmos DB**: Uses `AZURE_COSMOS_AUTHENTICATION_TYPE=managed_identity`
- ✅ **Redis**: Uses `REDIS_AUTH_TYPE=managed_identity`
- ✅ **Azure Search**: Uses `AZURE_SEARCH_AUTHENTICATION_TYPE=managed_identity`
- ✅ **Document Intelligence**: Uses `AZURE_DOCUMENT_INTELLIGENCE_AUTHENTICATION_TYPE=managed_identity`
- ✅ **OpenAI**: Uses token provider with DefaultAzureCredential

### No Keys/Secrets in Configuration
- ❌ No AZURE_COSMOS_KEY
- ❌ No AZURE_SEARCH_API_KEY
- ❌ No AZURE_DOCUMENT_INTELLIGENCE_API_KEY
- ❌ No REDIS_KEY
- ✅ Only App Registration secret (for user authentication)

### Role Propagation
- RBAC role assignments may take 5-10 minutes to propagate
- If you get authentication errors immediately after deployment, wait a few minutes

## 📝 Troubleshooting

### Container fails to start
```bash
# Check logs for errors
az containerapp logs show \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg \
  --tail 50
```

### Authentication errors
- Verify managed identity is assigned to Container App
- Check RBAC role assignments are present
- Wait 10 minutes for role propagation
- Verify resource endpoints are correct

### Cannot access application
```bash
# Check ingress configuration
az containerapp show \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg \
  --query "properties.configuration.ingress"
```

## 🔄 Update Workflow

### To update application code:
```bash
# Build and push new image
docker build -t containermiacrdev.azurecr.io/simplechat:latest .
docker push containermiacrdev.azurecr.io/simplechat:latest

# Restart Container App
az containerapp revision restart \
  --name containermi-dev-containerapp \
  --resource-group container-mi-rg
```

### To update infrastructure:
```bash
# Update .tfvars or .tf files
terraform plan -var-file="container-mi.tfvars"
terraform apply -var-file="container-mi.tfvars"
```

## 📚 Files Modified

- ✅ `containerapp.tf` - Added RBAC roles, switched to MI authentication
- ✅ `main.tf` - Added OpenAI data source
- ✅ `container-mi.tfvars` - Sample variables for your deployment
- ✅ `README.md` - Comprehensive deployment guide
- ✅ `config.py` - Updated version to 0.229.099

## 🎉 Success Criteria

Deployment is successful when:
1. Container App is running (`az containerapp show`)
2. All 6 RBAC roles are assigned
3. Application logs show Managed Identity authentication
4. Web UI is accessible
5. Can login with Azure AD
6. Admin settings page loads
7. No authentication errors in logs
