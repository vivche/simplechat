# GitHub Actions Workflow Quick Reference

**Version: 0.229.099**

## Quick Answer: Why No "Run workflow" Button?

**The "Run workflow" button doesn't appear for "SimpleChat Container APP Docker Image Publish" because the workflow file only exists on the `feature/containerize-app` branch, not on the `main` branch.**

GitHub Actions only shows the manual trigger button for workflows that exist on the **default branch** (main).

## Side-by-Side Comparison

| Feature | SimpleChat Docker Image Publish | SimpleChat Container APP Docker Image Publish |
|---------|--------------------------------|---------------------------------------------|
| **File Location** | `.github/workflows/docker_image_publish.yml` | `.github/workflows/docker_container_app_image_publish.yml` |
| **Branch** | ✅ `main` (default branch) | ❌ `feature/containerize-app` (feature branch) |
| **"Run workflow" Button** | ✅ **YES - Visible** | ❌ **NO - Not visible** |
| **Trigger Branches** | `main` | `feature/containerize-app` |
| **ACR Secrets** | `ACR_USERNAME`<br>`ACR_PASSWORD`<br>`ACR_LOGIN_SERVER` | `CONTAINER_ACR_USERNAME`<br>`CONTAINER_ACR_PASSWORD`<br>`CONTAINER_ACR_LOGIN_SERVER` |
| **Docker Image Name** | `simple-chat` | `simple-chat-container` |
| **Image Tags** | `simple-chat:<date>_<run>`<br>`simple-chat:latest` | `simple-chat-container:<date>_<run>`<br>`simple-chat-container:latest` |
| **Dockerfile** | `application/single_app/Dockerfile` | `Dockerfile` (root) |
| **Likely Target** | Azure App Service | Azure Container Apps |
| **Purpose** | Web App deployment | Container Apps deployment |

## How to Fix

### ✅ Solution: Merge the Workflow to Main

1. Merge `docker_container_app_image_publish.yml` from `feature/containerize-app` to `main`
2. The "Run workflow" button will appear immediately
3. You can keep it triggered by the feature branch if needed:

```yaml
on:
  push:
    branches:
    - main
    - feature/containerize-app  # Optional: keep feature branch trigger
  workflow_dispatch:
```

## Alternative: Use API to Trigger

If you must keep the workflow on the feature branch only:

```bash
# Using GitHub CLI
gh workflow run docker_container_app_image_publish.yml \
  --ref feature/containerize-app

# Using curl
curl -X POST \
  -H "Authorization: token YOUR_TOKEN" \
  https://api.github.com/repos/vivche/simplechat/actions/workflows/docker_container_app_image_publish.yml/dispatches \
  -d '{"ref":"feature/containerize-app"}'
```

## Visual Workflow Location

```
Repository: vivche/simplechat
│
├── main branch (DEFAULT) ✅
│   └── .github/workflows/
│       ├── docker_image_publish.yml ✅ HAS BUTTON
│       ├── docker_image_publish_dev.yml ✅ HAS BUTTON
│       ├── docker_image_publish_nadoyle.yml ✅ HAS BUTTON
│       └── enforce-dev-to-main.yml
│
└── feature/containerize-app branch ❌
    └── .github/workflows/
        └── docker_container_app_image_publish.yml ❌ NO BUTTON
```

## Key Takeaway

🔑 **Workflows must be on the default branch (`main`) to show the "Run workflow" button in the GitHub Actions UI, even if they have `workflow_dispatch` configured.**

---

For detailed explanation and additional solutions, see [WORKFLOW_COMPARISON_AND_MANUAL_TRIGGERS.md](./WORKFLOW_COMPARISON_AND_MANUAL_TRIGGERS.md)
