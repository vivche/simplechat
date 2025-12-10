# GitHub Actions Workflow Comparison and Manual Trigger Configuration

**Version: 0.229.099**  
**Implemented in version: 0.229.099**

## Overview

This document explains the differences between the two Docker image publishing workflows in the SimpleChat repository and clarifies why the "Run workflow" button appears for one workflow but not the other.

## Workflows Overview

### 1. SimpleChat Docker Image Publish
- **File**: `.github/workflows/docker_image_publish.yml`
- **Location**: main branch
- **Workflow Name**: "SimpleChat Docker Image Publish"
- **Status**: Active and visible in GitHub Actions UI with manual trigger button

### 2. SimpleChat Container APP Docker Image Publish
- **File**: `.github/workflows/docker_container_app_image_publish.yml`
- **Location**: feature/containerize-app branch (NOT on main branch)
- **Workflow Name**: "SimpleChat Container APP Docker Image Publish"
- **Status**: Active but manual trigger button NOT visible

## Key Differences

### Trigger Configuration

**SimpleChat Docker Image Publish (main branch)**:
```yaml
on:
  push:
    branches:
    - main
  workflow_dispatch:
```
- Triggers on push to `main` branch
- Has `workflow_dispatch` for manual triggering
- **Visible in UI with "Run workflow" button** ✅

**SimpleChat Container APP Docker Image Publish (feature branch)**:
```yaml
on:
  push:
    branches:
    - feature/containerize-app
  workflow_dispatch:
```
- Triggers on push to `feature/containerize-app` branch
- Has `workflow_dispatch` for manual triggering
- **"Run workflow" button NOT visible in main branch UI** ❌

### Azure Container Registry Secrets

**SimpleChat Docker Image Publish**:
- `ACR_USERNAME`
- `ACR_PASSWORD`
- `ACR_LOGIN_SERVER`

**SimpleChat Container APP Docker Image Publish**:
- `CONTAINER_ACR_USERNAME`
- `CONTAINER_ACR_PASSWORD`
- `CONTAINER_ACR_LOGIN_SERVER`

Different secret names suggest these workflows may target different Azure Container Registries, potentially for different deployment environments.

### Docker Image Tags

**SimpleChat Docker Image Publish**:
- Image name: `simple-chat`
- Tags: `simple-chat:<date>_<run_number>` and `simple-chat:latest`

**SimpleChat Container APP Docker Image Publish**:
- Image name: `simple-chat-container`
- Tags: `simple-chat-container:<date>_<run_number>` and `simple-chat-container:latest`

### Dockerfile Location

**SimpleChat Docker Image Publish**:
- Uses: `application/single_app/Dockerfile`
- Likely builds the web app for App Service deployment

**SimpleChat Container APP Docker Image Publish**:
- Uses: Root `Dockerfile`
- Likely builds for Azure Container Apps deployment

### Node.js Dependency Installation

**SimpleChat Docker Image Publish**:
```yaml
- name: Install Ajv
  run: npm install ajv@^8.0.0 ajv-cli@^5.0.0
- name: Install Ajv
  run: npm install ajv@^8.0.0 ajv-formats
```
Two separate steps with **duplicate step names** (⚠️ Note: This causes confusing logs in the GitHub Actions UI and should be fixed by using unique step names)

**SimpleChat Container APP Docker Image Publish**:
```yaml
- name: Install Ajv dependencies
  run: |
    npm install ajv@^8.0.0 ajv-cli@^5.0.0
    npm install ajv@^8.0.0 ajv-formats
```
Combined into a single step with better naming (✅ Improved approach)

## Why the "Run workflow" Button Doesn't Appear

### GitHub Actions Behavior

GitHub Actions has specific rules for displaying the "Run workflow" button:

1. **Default Branch Requirement**: The "Run workflow" button only appears for workflows that exist on the **default branch** (typically `main`)

2. **Workflow Visibility**: Even though a workflow has `workflow_dispatch` trigger, if the workflow file doesn't exist on the default branch, the manual trigger UI won't be shown

3. **Feature Branch Limitation**: Workflows that only exist on feature branches can be triggered by:
   - Push events to those branches
   - API calls to the workflow_dispatch endpoint
   - BUT NOT through the UI button

### Current Situation

**"SimpleChat Container APP Docker Image Publish"** doesn't show the "Run workflow" button because:
- The workflow file exists only in the `feature/containerize-app` branch
- GitHub Actions UI displays manual trigger buttons only for workflows on the default branch
- The workflow CAN run automatically when code is pushed to `feature/containerize-app`
- The workflow CANNOT be manually triggered from the GitHub UI

**"SimpleChat Docker Image Publish"** shows the button because:
- The workflow file exists on the `main` branch (default branch)
- The `workflow_dispatch` trigger is recognized and displayed in the UI

## Solutions and Recommendations

### Option 1: Merge to Main Branch (Recommended for Production)
If the Container APP workflow is ready for production:

1. **Merge the workflow file** from `feature/containerize-app` to `main`
2. **Update the trigger** to target appropriate branches:
   ```yaml
   on:
     push:
       branches:
       - main
       - feature/containerize-app  # Keep feature branch if needed
     workflow_dispatch:
   ```
3. The "Run workflow" button will appear once the file is on `main`

### Option 2: Keep Separate Workflows for Different Purposes
If the two workflows serve different purposes (e.g., App Service vs Container Apps):

1. **Merge the Container APP workflow to main** with a different name
2. **Configure different triggers** based on branch or path filters
3. **Use different secrets** to deploy to different environments

Example configuration:
```yaml
name: SimpleChat Container APP Docker Image Publish

on:
  push:
    branches:
    - main
    paths:
    - 'Dockerfile'  # Only trigger on root Dockerfile changes
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
        - dev
        - staging
        - production
```

### Option 3: Use Workflow Dispatch API
To manually trigger the workflow while it remains on the feature branch:

```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_PAT_TOKEN" \
  https://api.github.com/repos/vivche/simplechat/actions/workflows/docker_container_app_image_publish.yml/dispatches \
  -d '{"ref":"feature/containerize-app"}'
```

## Deployment Architecture Implications

The existence of two separate workflows suggests a multi-environment deployment strategy:

### SimpleChat Docker Image Publish (Main)
- **Target**: Azure App Service (Web App for Containers)
- **Image**: `simple-chat`
- **Dockerfile**: `application/single_app/Dockerfile`
- **Purpose**: Traditional web app deployment

### SimpleChat Container APP Docker Image Publish (Feature)
- **Target**: Azure Container Apps
- **Image**: `simple-chat-container`
- **Dockerfile**: Root `Dockerfile`
- **Purpose**: Cloud-native container deployment with Container Apps features

## Best Practices

1. **Consolidate Workflows**: If both workflows target the same deployment, consider merging them with environment-based inputs

2. **Document Purpose**: Add comments in workflow files explaining their specific purpose and target environment

3. **Consistent Naming**: Use clear, descriptive names that indicate the deployment target:
   - `docker-image-publish-appservice.yml`
   - `docker-image-publish-containerapps.yml`

4. **Secret Management**: Document which secrets are for which environment in the repository settings

5. **Branch Strategy**: Keep production workflows on `main`, use feature branches for testing new deployment approaches

## Testing the Solution

After merging the Container APP workflow to main:

1. Navigate to **Actions** tab in GitHub
2. Select **"SimpleChat Container APP Docker Image Publish"** from the workflows list
3. Verify the **"Run workflow"** button appears
4. Click the button and select the branch
5. Confirm the workflow runs successfully

## Conclusion

The "Run workflow" button doesn't appear for the "SimpleChat Container APP Docker Image Publish" workflow because the workflow file only exists on a feature branch, not on the default `main` branch. GitHub Actions only displays manual trigger buttons for workflows on the default branch.

To resolve this:
- Merge the workflow file to `main` if it's production-ready
- Adjust triggers to match your branching strategy
- Consider consolidating workflows if they serve the same purpose

The two workflows appear to serve different deployment targets (App Service vs Container Apps), which is a valid architecture for supporting multiple deployment options.
