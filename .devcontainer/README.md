# Running SimpleChat in Dev Container

This guide explains how to run the SimpleChat application inside a VS Code dev container for local development.

## Prerequisites

- **Docker Desktop** - Installed and running
- **VS Code** - With Dev Containers extension installed
- **Environment Variables** - Configured in `application/single_app/.env`

### Setup Environment Variables

If you don't have a `.env` file yet, create one from the sample:

```powershell
# Navigate to the application directory
cd application/single_app

# Copy the sample file
cp .env.sample .env

# Edit .env and fill in your actual Azure credentials
```

Make sure to replace all placeholder values in `.env` with your actual Azure service credentials before starting the dev container.

## Quick Start

### 1. Ensure Docker Desktop is Running

**IMPORTANT**: Before opening the dev container, make sure Docker Desktop is running on your machine.

1. Start Docker Desktop
2. Wait for it to fully start (Docker icon in system tray should show "Docker Desktop is running")
3. Verify Docker is running:
   ```powershell
   docker ps
   ```

### 2. Open in Dev Container

1. Open the `simplechat` folder in VS Code
2. Press `F1` (or `Ctrl+Shift+P`) → Type: `Dev Containers: Reopen in Container`
3. Wait for the container to build (2-3 minutes on first run - Docker will rebuild the image)

### 3. Verify App is Running

Once the container opens, check if the Flask app started automatically:

```bash
tail -f /tmp/flask.log
```

You should see Flask startup messages and Cosmos DB connection logs.

### 4. Access the Application

Open your browser and navigate to:
```
http://localhost:8000
```

## Troubleshooting

### App Not Running

Check if the Python process is running:
```bash
ps aux | grep python
```

If not running, start it manually:
```bash
nohup /app/venv/bin/python /app/app.py > /tmp/flask.log 2>&1 &
```

### Cannot Access localhost:8000

1. Verify port forwarding in VS Code:
   - Click "PORTS" tab in bottom panel
   - Port 8000 should be listed and forwarded

2. Check if the app is listening:
   ```bash
   tail -f /tmp/flask.log
   ```

### Restart the App

To restart the Flask app:
```bash
# Kill the existing process
pkill -f "python /app/app.py"

# Start it again
nohup /app/venv/bin/python /app/app.py > /tmp/flask.log 2>&1 &
```

## Development Workflow

### Making Code Changes

1. Edit files in VS Code (they auto-sync to the container)
2. Restart the Flask app (see above)
3. Refresh browser to see changes

### Rebuilding the Container

After changing `requirements.txt`, `Dockerfile`, or `devcontainer.json`:

1. Press `F1` (or `Ctrl+Shift+P`) → `Dev Containers: Rebuild Container`
2. Wait for rebuild to complete

### Exiting Dev Container

To return to your local environment:
- `F1` (or `Ctrl+Shift+P`) → `Dev Containers: Reopen Folder Locally`

## Configuration Details

- **Workspace Location**: `/workspaces/simplechat/` (your code mounts here)
- **App Location**: `/app/` (inside container)
- **Python Virtual Environment**: `/app/venv/`
- **Logs**: `/tmp/flask.log`
- **Port**: 8000 (forwarded to localhost:8000)
- **User**: `appuser` (non-root)

## Environment Variables

The dev container automatically loads environment variables from:
```
application/single_app/.env
```

Make sure this file contains all required Azure credentials and configuration before opening the dev container.

## Azure Authentication

For local development with Azure AD authentication:

1. Set in your `.env` file:
   ```
   LOGIN_REDIRECT_URL=http://localhost:8000/getAToken
   HOME_REDIRECT_URL=http://localhost:8000/
   ```

2. Add redirect URI in Azure Portal:
   - Azure Portal → App registrations → Your app
   - Authentication → Add URI: `http://localhost:8000/getAToken`

## Need Help?

- Check logs: `tail -f /tmp/flask.log`
- Check running processes: `ps aux | grep python`
- Verify port forwarding in VS Code PORTS panel
