# Migration Summary: App Service to Container Apps with Managed Identity

**Date**: December 11, 2025  
**Branch**: `containerize-app-mi`  
**Status**: 95% Complete - Redis session persistence blocking full functionality

---

## Goal
Migrate SimpleChat application from Azure App Service (using key-based authentication) to Azure Container Apps with Managed Identity authentication for all Azure services.

---

## Infrastructure Completed ✅

### Terraform Configuration
**Location**: `deployers/terraform-containerapp-mi/`

**What We Built**:
1. **Automated App Registration** - Terraform now creates and manages the Entra ID app registration automatically
2. **Redirect URI Automation** - Null resource with local-exec updates redirect URIs after container app deployment
3. **Managed Identity Setup**:
   - System-Assigned Identity: `9bbde2dd-0e4b-4b09-bce0-223846ffedb5` (primary for all services)
   - User-Assigned Identity: `af324388-edc8-488b-a4ff-d7d21341c740` (for ACR pull)

### Services Configured with Managed Identity
All working successfully:
- ✅ **Cosmos DB** - Custom SQL RBAC role "SimpleChat Database Owner" (`2bb83c32-59fc-4d7f-a7ab-9dd00331f459`) with database creation permissions
- ✅ **Azure OpenAI** - Cognitive Services OpenAI User role
- ✅ **AI Search** - Search Index Data Contributor + Search Service Contributor roles
- ✅ **Document Intelligence** - Cognitive Services User role
- ✅ **Storage Account** - Storage Blob Data Contributor role
- ✅ **Container Registry** - AcrPull role (using User-Assigned identity)
- ⚠️ **Redis Cache** - Redis Cache Contributor role assigned, but authentication still failing (current issue)

---

## Docker & Deployment

### Container Images Built
**Registry**: `containermiacrdev.azurecr.io/simple-chat-container`

Images built tonight: `2025-12-11_1` through `2025-12-11_13`
- Current deployed: `2025-12-11_12` (revision 0000010)
- Next build: `2025-12-11_13` (pending deployment)

### Container App Details
- **Name**: `containermi-dev-containerapp`
- **Resource Group**: `container-mi-rg`
- **Region**: `eastus2`
- **URL**: https://containermi-dev-containerapp.calmmushroom-7bd24677.eastus2.azurecontainerapps.io
- **Current Revision**: `containermi-dev-containerapp--0000010`

---

## Issues Resolved ✅

### 1. Cosmos DB Permissions
**Problem**: Managed Identity couldn't create new databases  
**Solution**: Created custom SQL RBAC role with `Microsoft.DocumentDB/databaseAccounts/sqlDatabases/*` DataActions

### 2. Redirect URI Mismatch
**Problem**: OAuth redirect URIs not matching container app FQDN  
**Solution**: Added terraform null_resource with `az ad app update` to automatically update redirect URIs post-deployment

### 3. Redis RBAC Setup
**Problem**: Redis required explicit role assignment for System-Assigned identity  
**Solution**: Added `azurerm_role_assignment` for Redis Cache Contributor role to System-Assigned MI

---

## Current Issue ❌ - Redis Managed Identity Authentication

### Problem
Sessions don't persist after login - immediate 401 Unauthorized errors.

### Root Cause
Redis Cache with Managed Identity requires:
- **Username**: Managed Identity Object ID (`9bbde2dd-0e4b-4b09-bce0-223846ffedb5`)
- **Password**: Fresh access token for scope `https://containermi-dev-redis.cacheinfra.windows.net:10225/appid`

### What We Tried

**Attempt 1-3**: Hardcoded object ID, static token approaches ❌
- Tokens expire, connections from pool fail

**Attempt 4-7**: Dynamic token extraction, custom connection class ❌
- Created `ManagedIdentityConnection` extending `SSLConnection`
- Implemented token refresh in `on_connect()` method
- Used `ConnectionPool` to pass custom connection class
- Problem: SSLConnection's `on_connect()` calls commands that require auth before we authenticate

**Attempt 8-10**: AUTH command timing fixes ❌
- Tried AUTH after `super().on_connect()` - failed (parent sends PING first)
- Tried AUTH before `super().on_connect()` - currently testing

### Current Code State
**File**: `application/single_app/app.py`

Two initialization functions (need to stay synchronized):
1. `_initialize_session_at_startup()` - lines 102-165
2. `_initialize_session()` - lines 219-290

Both implement:
```python
class ManagedIdentityConnection(SSLConnection):
    def on_connect(self):
        # Get fresh token from DefaultAzureCredential
        # Extract object ID from JWT token payload
        # Send AUTH command BEFORE super().on_connect()
        # Let parent do PING/other setup
```

### Error Messages
```
Authentication required.
  at redis/connection.py line 492 in on_connect
  at app.py line 280 in on_connect
```

---

## Commits Made Tonight

1. `caea7c1` - "Extract MI object ID dynamically from access token"
2. `3b0dd3a` - "Use custom Redis connection class with token refresh"
3. `c446f92` - "Fix Redis connection - use ConnectionPool instead of passing connection_class to Redis()"
4. `ba339eb` - "Fix _initialize_session_at_startup to use ConnectionPool - synchronize both session init functions"
5. `9bdab58` - "Fix Redis MI auth: call super().on_connect() BEFORE AUTH command, add debug logging"
6. `9e9e617` - "Fix Redis MI auth: send AUTH BEFORE super().on_connect() to authenticate before PING"

---

## Next Steps (For Tomorrow)

### 1. Deploy and Test Image 2025-12-11_13
```powershell
az containerapp update --name containermi-dev-containerapp --resource-group container-mi-rg --image containermiacrdev.azurecr.io/simple-chat-container:2025-12-11_13
```

Check logs for:
- "Redis AUTH response (startup): OK" ✅
- "Redis AUTH response (before-first-request): OK" ✅
- No "Authentication required" errors ✅

### 2. If Still Failing - Alternative Approaches

**Option A**: Use redis-py's built-in token provider pattern
- Research if redis-py 5.x has native Azure MI support
- May need to upgrade redis-py version

**Option B**: Override more of SSLConnection lifecycle
- Don't call `super().on_connect()` at all
- Manually implement socket connection + AUTH + PING sequence

**Option C**: Use Redis connection string with token
- Some Redis clients support connection strings with tokens
- May require different library or approach

**Option D**: Fallback to key-based auth temporarily
- Get Redis access key from Azure
- Store in environment variable
- Switch back to MI once working pattern found

### 3. Clean Up After Success
- Remove debug logging from `route_frontend_authentication.py` (lines 143-157)
- Remove `print()` statements showing session keys
- Consider consolidating the two initialization functions
- Add terraform state files to `.gitignore`
- Update application version in `config.py`

### 4. Documentation
- Document the MI authentication pattern for Redis
- Create troubleshooting guide for common MI issues
- Update deployment README with new terraform structure

---

## Key Files Modified

**Terraform**:
- `deployers/terraform-containerapp-mi/*.tf` (all infrastructure)

**Application Code**:
- `application/single_app/app.py` (Redis MI connection logic)
- `application/single_app/route_frontend_authentication.py` (debug logging)

**Docker**:
- `Dockerfile` (unchanged - working correctly)

---

## Environment Configuration

All services configured in terraform to use **AUTHENTICATION_TYPE = managed_identity**:
- `AZURE_COSMOS_AUTHENTICATION_TYPE=managed_identity`
- `AZURE_OPENAI_GPT_AUTHENTICATION_TYPE=managed_identity`
- `AZURE_OPENAI_EMBEDDING_AUTHENTICATION_TYPE=managed_identity`
- `AZURE_OPENAI_IMAGE_GEN_AUTHENTICATION_TYPE=managed_identity`
- `AZURE_AI_SEARCH_AUTHENTICATION_TYPE=managed_identity`
- `AZURE_DOCUMENT_INTELLIGENCE_AUTHENTICATION_TYPE=managed_identity`
- `REDIS_AUTH_TYPE=managed_identity`

No API keys stored in environment variables (all empty/removed from terraform).

---

## Success Criteria
- [x] Infrastructure deploys successfully
- [x] OAuth login flow completes
- [x] All non-Redis services working with MI
- [ ] **Sessions persist after login** ← CURRENT BLOCKER
- [ ] User can access chat interface
- [ ] Chat messages work end-to-end
- [ ] No 401 Unauthorized errors

---

## Quick Reference Commands

**Check logs**:
```powershell
az containerapp logs show --name containermi-dev-containerapp --resource-group container-mi-rg --tail 200 | Select-String "AUTH|401|Error" -Context 2,2
```

**Check ACR images**:
```powershell
az acr repository show-tags --name containermiacrdev --repository simple-chat-container --orderby time_desc --output table
```

**Update container app**:
```powershell
az containerapp update --name containermi-dev-containerapp --resource-group container-mi-rg --image containermiacrdev.azurecr.io/simple-chat-container:2025-12-11_XX
```

**Check MI assignments**:
```powershell
az role assignment list --assignee 9bbde2dd-0e4b-4b09-bce0-223846ffedb5 --all --output table
```

**Check Redis connection directly**:
```powershell
# Get access token
$token = az account get-access-token --resource https://containermi-dev-redis.cacheinfra.windows.net:10225/appid --query accessToken -o tsv

# Test with redis-cli (if available)
redis-cli -h containermi-dev-redis.redis.cache.windows.net -p 6380 --tls --user 9bbde2dd-0e4b-4b09-bce0-223846ffedb5 --pass $token PING
```

---

## Technical Details

### Redis Managed Identity Authentication Flow
1. Container app starts with System-Assigned Managed Identity enabled
2. Application uses `DefaultAzureCredential()` to acquire tokens
3. Token scope: `https://{redis-hostname}.cacheinfra.windows.net:10225/appid`
4. Extract Object ID from JWT token payload (base64 decode)
5. Use Object ID as username, access token as password
6. Send AUTH command to Redis before any other commands
7. Connection pool creates fresh connections with current tokens

### Current Implementation Pattern
```python
from azure.identity import DefaultAzureCredential
from redis.connection import SSLConnection, ConnectionPool
from redis import Redis

credential = DefaultAzureCredential()
token_scope = "https://containermi-dev-redis.cacheinfra.windows.net:10225/appid"

class ManagedIdentityConnection(SSLConnection):
    _credential = credential
    _token_scope = token_scope
    
    def on_connect(self):
        # Get fresh token
        token = self._credential.get_token(self._token_scope)
        
        # Extract username from JWT
        import base64, json
        payload = token.token.split('.')[1]
        payload += '=' * (4 - len(payload) % 4)
        token_data = json.loads(base64.urlsafe_b64decode(payload))
        username = token_data.get('oid', '')
        
        # Authenticate BEFORE parent's on_connect
        self.send_command('AUTH', username, token.token)
        auth_response = self.read_response()
        
        # Let parent do PING/setup
        super().on_connect()

pool = ConnectionPool(
    connection_class=ManagedIdentityConnection,
    host='containermi-dev-redis.redis.cache.windows.net',
    port=6380,
    credential=credential,
    token_scope=token_scope,
    socket_connect_timeout=5,
    socket_timeout=5,
    decode_responses=False
)

redis_client = Redis(connection_pool=pool)
```

---

## Resources & References

**Azure Documentation**:
- [Use Microsoft Entra ID for cache authentication](https://learn.microsoft.com/en-us/azure/azure-cache-for-redis/cache-azure-active-directory-for-authentication)
- [Container Apps Managed Identity](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity)
- [Cosmos DB RBAC](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-setup-rbac)

**Python Libraries**:
- `azure-identity` - DefaultAzureCredential for MI token acquisition
- `redis` - Redis client with connection pool support
- `Flask-Session` - Server-side session management

---

**End of Summary** - Resume work by deploying image `2025-12-11_13` and checking logs for AUTH success! 🚀
