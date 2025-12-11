# Step-by-Step Guide: Deploy SimpleChat Infrastructure with Terraform

## 📋 Prerequisites Completed

✅ Resource Group: `container-mi-rg` (created via PowerShell)  
✅ Azure Container Registry: `containermiacrdev.azurecr.io` (created via PowerShell)  
✅ Azure OpenAI: `containermi-openai-dev` (created via PowerShell)

## 🎯 What You'll Create

This Terraform deployment will create:
1. **User-Assigned Managed Identity** (`containermi-dev-id`)
2. **Cosmos DB Account** (`containermi-dev-cosmos`)
3. **Azure AI Search** (`containermi-dev-search`)
4. **Document Intelligence** (`containermi-dev-docintel`)
5. **Redis Cache** (`containermi-dev-redis`)
6. **Log Analytics Workspace** (`containermi-dev-law`)
7. **Application Insights** (`containermi-dev-ai`)
8. **Container App Environment** (hosting infrastructure)
9. **Container App** (SimpleChat application)
10. **6 RBAC Role Assignments** (Managed Identity permissions)

## 📝 Step 1: Create Azure AD App Registration

First, create an app registration for user authentication:

```powershell
# Login to Azure
az login
az account set --subscription e88b99f7-323e-408d-91b9-527f33c00ac7

# Create app registration
$appReg = az ad app create --display-name "SimpleChat-ContainerMI" --sign-in-audience AzureADMyOrg | ConvertFrom-Json

# Save the Application (Client) ID
$clientId = $appReg.appId
Write-Host "Client ID: $clientId" -ForegroundColor Green

# Create a client secret
$secret = az ad app credential reset --id $clientId | ConvertFrom-Json
$clientSecret = $secret.password
Write-Host "Client Secret: $clientSecret" -ForegroundColor Yellow

# IMPORTANT: Save these values - you'll need them next
Write-Host "`nSave these values:" -ForegroundColor Cyan
Write-Host "CLIENT_ID: $clientId"
Write-Host "CLIENT_SECRET: $clientSecret"
```

## 📝 Step 2: Get Your Tenant ID

```powershell
$tenantId = az account show --query tenantId -o tsv
Write-Host "Tenant ID: $tenantId" -ForegroundColor Green
```

## 📝 Step 3: Update container-mi.tfvars

Edit the file `deployers\terraform-containerapp\container-mi.tfvars`:

```powershell
cd C:\Source\DIA\ContainerMIChat\simplechat\deployers\terraform-containerapp
code container-mi.tfvars
```

Update these three values:
```hcl
param_tenant_id                    = "YOUR_TENANT_ID_FROM_STEP_2"
param_app_registration_client_id   = "YOUR_CLIENT_ID_FROM_STEP_1"
param_app_registration_secret      = "YOUR_CLIENT_SECRET_FROM_STEP_1"
```

## 📝 Step 4: Build and Push Docker Image

```powershell
# Navigate to repository root
cd C:\Source\DIA\ContainerMIChat\simplechat

# Login to ACR
az acr login --name containermiacrdev

# Build the image
docker build -t containermiacrdev.azurecr.io/simplechat:latest .

# Push to ACR
docker push containermiacrdev.azurecr.io/simplechat:latest
```

## 📝 Step 5: Initialize Terraform

```powershell
cd C:\Source\DIA\ContainerMIChat\simplechat\deployers\terraform-containerapp

# Initialize Terraform (downloads providers)
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

## 📝 Step 6: Review the Deployment Plan

```powershell
# Create execution plan
terraform plan -var-file="container-mi.tfvars" -out=containermi.tfplan
```

Review the plan - you should see:
- ✅ **7 resources to create** (infrastructure.tf)
- ✅ **2 resources to create** (container environment + app)
- ✅ **6 role assignments to create** (RBAC permissions)
- ✅ **Total: ~15 resources**

## 📝 Step 7: Deploy Infrastructure

```powershell
# Apply the plan
terraform apply containermi.tfplan
```

This will take **5-10 minutes**. You'll see resources being created:
```
azurerm_user_assigned_identity.id: Creating...
azurerm_log_analytics_workspace.law: Creating...
azurerm_cosmosdb_account.cosmos: Creating...
azurerm_search_service.search: Creating...
...
```

## 📝 Step 8: Verify Deployment

```powershell
# Get the Container App URL
terraform output containerapp_url

# Check Container App status
az containerapp show `
  --name containermi-dev-containerapp `
  --resource-group container-mi-rg `
  --query "properties.runningStatus"
```

Expected output: `"Running"`

## 📝 Step 9: Verify RBAC Roles

```powershell
# Get managed identity principal ID
$principalId = az identity show `
  --name containermi-dev-id `
  --resource-group container-mi-rg `
  --query principalId -o tsv

# List all role assignments
az role assignment list `
  --assignee $principalId `
  --all `
  --query "[].{Role:roleDefinitionName, Scope:scope}" `
  --output table
```

You should see **6 roles**:
- ✅ AcrPull
- ✅ Cosmos DB Built-in Data Contributor
- ✅ Search Index Data Contributor
- ✅ Cognitive Services User
- ✅ Redis Cache Contributor
- ✅ Cognitive Services OpenAI User

## 📝 Step 10: Check Application Logs

```powershell
# View real-time logs
az containerapp logs show `
  --name containermi-dev-containerapp `
  --resource-group container-mi-rg `
  --follow
```

Look for successful authentication:
```
✅ Cosmos DB initialized using Managed Identity
✅ Redis enabled using Managed Identity
✅ Azure AI Search initialized with Managed Identity
```

Press `Ctrl+C` to stop following logs.

## 📝 Step 11: Access the Application

```powershell
# Get the URL
$appUrl = terraform output -raw containerapp_url
Write-Host "Application URL: $appUrl" -ForegroundColor Green

# Open in browser
Start-Process $appUrl
```

## 📝 Step 12: Configure in Admin UI

After accessing the application:

1. **Login** with your Azure AD account
2. Navigate to **Admin Settings**
3. Configure:
   - ✅ AI Search Indexes (upload JSON schemas)
   - ✅ GPT Model deployments
   - ✅ Embedding model
   - ✅ Verify Document Intelligence connection
   - ✅ Optional: Content Safety, Storage Account

## 🔍 Troubleshooting

### Issue: "Authentication failed" errors

**Wait 5-10 minutes** for RBAC roles to propagate, then:

```powershell
# Restart the container app
az containerapp revision restart `
  --name containermi-dev-containerapp `
  --resource-group container-mi-rg
```

### Issue: Container not starting

```powershell
# Check logs for errors
az containerapp logs show `
  --name containermi-dev-containerapp `
  --resource-group container-mi-rg `
  --tail 50
```

### Issue: Can't access application

```powershell
# Check ingress configuration
az containerapp show `
  --name containermi-dev-containerapp `
  --resource-group container-mi-rg `
  --query "properties.configuration.ingress"
```

## 🎉 Success Indicators

Deployment is successful when you see:

- ✅ `terraform apply` completes without errors
- ✅ Container App status = "Running"
- ✅ 6 RBAC roles assigned to managed identity
- ✅ Application URL accessible in browser
- ✅ Can login with Azure AD
- ✅ Admin settings page loads
- ✅ Logs show Managed Identity authentication messages

## 🔄 Update the Application

To update code after initial deployment:

```powershell
# From repository root
cd C:\Source\DIA\ContainerMIChat\simplechat

# Build new image
docker build -t containermiacrdev.azurecr.io/simplechat:latest .
docker push containermiacrdev.azurecr.io/simplechat:latest

# Restart Container App to pull new image
az containerapp revision restart `
  --name containermi-dev-containerapp `
  --resource-group container-mi-rg
```

## 🗑️ Cleanup (if needed)

To destroy everything:

```powershell
cd C:\Source\DIA\ContainerMIChat\simplechat\deployers\terraform-containerapp
terraform destroy -var-file="container-mi.tfvars"
```

**Note:** This does NOT delete the resource group, ACR, or OpenAI created by PowerShell.

## 📊 Resources Created Summary

| Resource | Name | Type | Purpose |
|----------|------|------|---------|
| Managed Identity | `containermi-dev-id` | User-Assigned | Authentication to all services |
| Cosmos DB | `containermi-dev-cosmos` | Database | Data storage |
| AI Search | `containermi-dev-search` | Search Service | Document indexing |
| Doc Intelligence | `containermi-dev-docintel` | Cognitive Service | Document processing |
| Redis | `containermi-dev-redis` | Cache | Session storage |
| Log Analytics | `containermi-dev-law` | Monitoring | Logging workspace |
| App Insights | `containermi-dev-ai` | Monitoring | Application telemetry |
| Container Env | `containermi-dev-containerenv` | Infrastructure | Container hosting |
| Container App | `containermi-dev-containerapp` | Application | SimpleChat app |

## ✅ Next Steps

After successful deployment:
1. Configure AI Search indexes in Admin UI
2. Test chat functionality
3. Upload documents to workspaces
4. Configure optional features (Video Indexer, Content Safety)
5. Monitor application performance in Application Insights
