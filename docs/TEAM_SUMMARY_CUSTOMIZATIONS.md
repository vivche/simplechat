# SimpleChat Customizations Summary
**Date:** December 11, 2025  
**Version:** 0.229.105  
**Audience:** Development Team

---

## Overview

Both terraform templates and python codes have drifted away from the source repo where I downloaded from main branch a few days ago. In order to support the following areas, we (copilot and I) had to make code changes:

---

## Enhancements Made

### 1) To support both key and MI authentication
- All Azure services now support both authentication methods via `AZURE_*_AUTHENTICATION_TYPE` environment variables
- Pattern: `DefaultAzureCredential(**managed_identity_credential_kwargs)` used consistently throughout codebase
- **Critical:** Services requiring managed identity (OpenAI, Document Intelligence) MUST have custom subdomains configured
- Reference: See `config.py` lines 217-224 for the `managed_identity_credential_kwargs` pattern
- Services supporting dual authentication:
  - Cosmos DB
  - Azure OpenAI (GPT, Embedding, Image Generation)
  - Document Intelligence
  - Azure AI Search
  - Storage Account
  - Redis Cache

### 2) To support both public and gov clouds
- Dynamic endpoint/scope configuration based on `AZURE_PLATFORM` environment variable
- Token scopes automatically adjusted:
  - **Commercial:** `cognitiveservices.azure.com/.default`, `search.azure.com/.default`
  - **Government:** `cognitiveservices.azure.us/.default`, `search.azure.us/.default`
- OIDC metadata URLs and authority hosts configured per cloud environment
- Reference: See `config.py` lines 180-210 for cloud-specific configurations
- Supports: `AzureCloud` (Commercial) and `AzureUSGovernment` (GovCloud)

### 3) To support both filesystem and redis session persistence
- Current configuration: Filesystem sessions (`SESSION_TYPE = 'filesystem'`)
- **Known Issue:** Session expiration occurring after ~7 seconds due to `/tmp` not being shared between container instances
- Redis infrastructure already deployed and ready (containermi-dev-redis)
- **Action Required:** Switch `SESSION_TYPE` to `'redis'` to fix session persistence issues
- Managed identity role already assigned: Redis Cache Contributor

---

## Additional Changes (December 10-11, 2025)

### 4) GitHub Actions CI/CD Pipeline for Container Apps

**New Workflow Added:** `.github/workflows/container_app_mi_image_publish.yml`
- Automated Docker image build and push to Azure Container Registry
- Triggers on push to `containerize-app-mi` branch or manual workflow dispatch
- **Key Steps:**
  1. Login to ACR using service principal credentials (secrets)
  2. Checkout code
  3. Generate JSON schema validators (using Ajv)
  4. Build Docker image with timestamp tag: `YYYY-MM-DD_$GITHUB_RUN_NUMBER`
  5. Tag as `latest` and push both tags to ACR
- **Benefits:** Consistent, reproducible builds without local Docker requirements
- **Image Naming:** `containermiacrdev.azurecr.io/simple-chat-container:2025-12-11_29`

### 5) Cosmos DB Container Creation Exception Handling

**Problem Solved:**
- Application would crash if Cosmos containers already existed during startup
- Common scenario when redeploying or updating container app

**Fix Applied:** (commit 8810003)
- Added proper exception handling for `CosmosResourceExistsError`
- Application now gracefully handles pre-existing containers
- Uses `create_container_if_not_exists()` with try/except blocks
- Falls back to `get_container_client()` if container exists
- **Impact:** Smoother deployments and container restarts

### 6) Multi-Cloud Azure AI Search and Redis Authentication Fixes (v0.229.104)

**Issues Fixed:**
- Azure AI Search credential scopes were hardcoded for public cloud
- Azure Function plugin used wrong ARM scope for government cloud
- Redis authentication not cloud-aware

**Changes Made:** (commits 978af11, 35f91f4, 958773d, e47ce7b, 484e921)
- Azure AI Search now uses **data plane scope** instead of ARM scope:
  - Public: `https://search.azure.com/.default`
  - Government: `https://search.azure.us/.default`
- Azure Function plugin uses correct ARM endpoint per cloud
- Redis authentication adapted for cloud environment
- **Files Updated:**
  - `config.py` - Cloud-aware scope configuration
  - `route_backend_settings.py` - Search test connection fixes
  - `semantic_kernel_plugins/azure_function_plugin.py` - ARM scope fixes

### 7) Azure AI Search RBAC Support (commit d3781a5)

**Enhancement:**
- Added support for both role-based access control (RBAC) and API key authentication
- Changed search service from `apiKeyOnly` to `aadOrApiKey` mode
- Enables managed identity authentication while maintaining API key fallback
- **Configuration:** `authentication_failure_mode = "http401WithBearerChallenge"`

### 8) User-Assigned Managed Identity Implementation (v0.229.105)

**Critical Prerequisites:**
- ⚠️ **Custom Cosmos DB Role Required:** Created custom role "SimpleChat Database Owner" (ID: `2bb83c32-59fc-4d7f-a7ab-9dd00331f459`)
  - **Why needed:** Built-in Cosmos DB roles don't allow container/database creation
  - **Permissions:** Allows application to create containers, read/write data, and manage database structure
  - **Must be created BEFORE deploying with managed identity**
  - See PowerShell script for role definition and assignment

**What Changed:**
- Updated 8 files to consistently use user-assigned MI instead of system-assigned MI
- Fixed Azure AI Search to support RBAC authentication (changed from `apiKeyOnly` to `aadOrApiKey` mode)
- All role assignments consolidated to user-assigned MI (containermi-dev-id)
- New environment variable added: `USER_ASSIGNED_MANAGED_IDENTITY_CLIENT_ID`

**Files Modified:**
1. `application/single_app/config.py` - Core MI configuration and credential pattern
2. `application/single_app/route_backend_settings.py` - Admin connection test functions
3. `application/single_app/route_backend_chats.py` - GPT and image generation clients
4. `application/single_app/functions_content.py` - Embedding client
5. `application/single_app/functions_documents.py` - Document processing GPT clients
6. `application/single_app/functions_authentication.py` - Video Indexer authentication
7. `deployers/azurecli/deploy-simplechat.ps1` - PowerShell deployment script
8. `deployers/terraform-containerapp-mi/infrastructure.tf` - Terraform search configuration

**Why This Matters:**
- Centralized identity management with explicit role assignments
- Easier to audit and manage permissions
- Eliminates confusion between system-assigned and user-assigned identities
- All services now use the same identity (af324388-edc8-488b-a4ff-d7d21341c740)

### 9) Deployment Scripts Updated

**PowerShell Script (deploy-simplechat.ps1):**
- Now includes `--custom-domain` flag for Cognitive Services creation/updates
- Azure AI Search creation includes RBAC configuration flags:
  ```powershell
  --auth-options aadOrApiKey --aad-auth-failure-mode http401WithBearerChallenge
  ```
- Automatically updates existing search services to enable both AAD and API key authentication

**Terraform Templates:**
- Updated `infrastructure.tf` with Azure AI Search authentication configuration:
  ```hcl
  authentication_failure_mode = "http401WithBearerChallenge"
  local_authentication_enabled = true  # aadOrApiKey mode
  ```

---

## Terraform Synchronization Requirements

**Items Needing Updates in Terraform Templates:**

- [ ] **Cosmos DB Custom Role:** Ensure custom role "SimpleChat Database Owner" is created
  - **Critical:** Must exist before role assignment in Terraform
  - Role ID: `2bb83c32-59fc-4d7f-a7ab-9dd00331f459`
  - Allows container creation, data operations, and database management
  - See PowerShell script `deploy-simplechat.ps1` for role definition

- [ ] **Document Intelligence:** Add `custom_subdomain_name` parameter to resource definition
  ```hcl
  custom_subdomain_name = "${local.param_base_name}-docintel"
  ```

- [ ] **Azure AI Search:** Add second role assignment for "Search Service Contributor"
  - Currently only has "Search Index Data Contributor"
  - Need both roles for full functionality

- [ ] **Container App:** Add `USER_ASSIGNED_MANAGED_IDENTITY_CLIENT_ID` environment variable
  ```hcl
  env {
    name  = "USER_ASSIGNED_MANAGED_IDENTITY_CLIENT_ID"
    value = azurerm_user_assigned_identity.id.client_id
  }
  ```

- [ ] **Image Generation OpenAI:** Add role assignment for tacd-openai resource (if managing via Terraform)
  - Resource: tacd-openai in tacd-ai resource group
  - Role: Cognitive Services OpenAI User

**Recommendation:** Review `docs/USER_ASSIGNED_MANAGED_IDENTITY_IMPLEMENTATION_SUMMARY.md` for detailed code examples.

---

## Current Status

### ✅ Working Components
- All Azure service connections operational (verified via admin settings tests)
- User-assigned managed identity functional with all required role assignments:
  - **Cosmos DB: SimpleChat Database Owner (CUSTOM ROLE - manually created)**
    - Role ID: `2bb83c32-59fc-4d7f-a7ab-9dd00331f459`
    - Allows creating containers/databases (not available in built-in roles)
  - Azure OpenAI: Cognitive Services OpenAI User (2 resources)
  - Document Intelligence: Cognitive Services User
  - Azure AI Search: Search Index Data Contributor + Search Service Contributor
  - Storage Account: Storage Blob Data Contributor
  - Redis Cache: Redis Cache Contributor
  - Container Registry: AcrPull
- GPT chat functionality working (after MI fixes)
- Admin settings connection tests passing
- Container app running on revision v0229105-184155

### ⚠️ Known Issues
- **Session Persistence:** Users experience session expiration after ~7 seconds
  - Root cause: Filesystem sessions stored in `/tmp` not shared between container instances
  - Impact: "Failed to load members" and "Failed to add member" errors in group management
  - Workaround: Use InPrivate/incognito browser sessions
  - **Solution:** Enable Redis for distributed session storage

### 🔄 Pending Actions
- Terraform templates need updates to match deployed configuration (see requirements above)
- Enable Redis session storage to fix persistence issues
- Consider removing deprecated system-assigned MI from container app

---

## Reference Information

### Documentation
- **Full Implementation Details:** `docs/USER_ASSIGNED_MANAGED_IDENTITY_IMPLEMENTATION_SUMMARY.md`
- **Current Version:** 0.229.105
- **Active Container Revision:** v0229105-184155
- **Latest Container Image:** containermiacrdev.azurecr.io/simple-chat-container:2025-12-11_29

### Key Configuration

**Managed Identities:**
```
User-Assigned MI:
  Name:        containermi-dev-id
  Client ID:   be436314-dbbb-4b23-a2b4-bb469824d062
  Principal ID: af324388-edc8-488b-a4ff-d7d21341c740

System-Assigned MI (deprecated):
  Principal ID: 9bbde2dd-0e4b-4b09-bce0-223846ffedb5
```

**Critical Environment Variables:**
```bash
USER_ASSIGNED_MANAGED_IDENTITY_CLIENT_ID=be436314-dbbb-4b23-a2b4-bb469824d062
AZURE_PLATFORM=AzureCloud  # or AzureUSGovernment

# All services use managed_identity authentication:
AZURE_COSMOS_AUTHENTICATION_TYPE=managed_identity
AZURE_OPENAI_GPT_AUTHENTICATION_TYPE=managed_identity
AZURE_OPENAI_EMBEDDING_AUTHENTICATION_TYPE=managed_identity
AZURE_OPENAI_IMAGE_GEN_AUTHENTICATION_TYPE=managed_identity
AZURE_DOCUMENT_INTELLIGENCE_AUTHENTICATION_TYPE=managed_identity
AZURE_AI_SEARCH_AUTHENTICATION_TYPE=managed_identity
```

---

## Key Takeaways for Team

1. **Flexibility Gained:** Our codebase is more flexible than upstream repository
   - Supports multiple authentication methods (key-based and managed identity)
   - Supports multiple cloud environments (commercial and government)
   - Supports multiple session storage backends (filesystem and Redis)

2. **Before Syncing with Upstream:**
   - Ensure these capabilities aren't lost during merge
   - Document any conflicts between our customizations and upstream changes
   - Consider contributing useful patterns back to upstream repository

3. **Immediate Priorities:**
   1. Enable Redis session storage to fix user experience issues
   2. Update Terraform templates to match current working configuration
   3. Test full deployment from Terraform to ensure reproducibility

4. **Long-Term Considerations:**
   - Maintain customization documentation as code evolves
   - Establish process for incorporating upstream changes while preserving enhancements
   - Consider feature flags for toggling between upstream and custom behaviors

---

## Git Commits Reference

**Commit 1:** "Changes for support using MI for auth" (Dec 10)
- Initial managed identity support groundwork

**Commit 2:** "Added a new github action for building container app image using MI for auth" (Dec 10)
- Automated CI/CD pipeline for container builds

**Commit 3:** "Added exception handling when the cosmos container already exists" (Dec 10)
- Improved deployment reliability

**Commit 4:** "Fix Azure AI Search credential_scopes error for public cloud" (Dec 11)
- Multi-cloud authentication fixes begin

**Commit 5-7:** Azure AI Search data plane scope fixes for all clouds (Dec 11)
- Comprehensive multi-cloud authentication support

**Commit 8:** "Multi-cloud support: Fix Azure AI Search, Azure Function plugin, and Redis auth" - v0.229.104 (Dec 11)
- Consolidated multi-cloud fixes

**Commit 9:** "Add user-assigned managed identity support for all Azure service authentication" (Dec 11)
- Initial MI support in config.py and route_backend_settings.py

**Commit 10:** "Updated to support both role-based access control and API key for Azure Search service" (Dec 11)
- Azure AI Search RBAC enablement

**Commit 11:** "Fix: Use user-assigned MI consistently throughout application" - v0.229.105 (Dec 11)
- Comprehensive MI fixes across 5 Python files
- Ensures all Azure service calls use user-assigned MI
- Fixes 401 PermissionDenied errors during runtime operations

---

## Questions or Issues?

For detailed technical information, consult:
- `docs/USER_ASSIGNED_MANAGED_IDENTITY_IMPLEMENTATION_SUMMARY.md`
- Azure Container Apps logs: `az containerapp logs show --name containermi-dev-containerapp`
- Container revision history: `az containerapp revision list --name containermi-dev-containerapp`

**Document Version:** 1.0  
**Last Updated:** December 11, 2025 23:59 UTC  
**Authors:** Vivien Chen & GitHub Copilot
