#!/bin/bash
# Start Flask app in the background with proper process management

echo "Starting Flask app..."

# Kill any existing Flask processes using find instead of pkill
find /proc -name cmdline 2>/dev/null | xargs grep -l "python.*app.py" 2>/dev/null | while read f; do
    pid=$(echo $f | cut -d'/' -f3)
    kill -9 $pid 2>/dev/null || true
done

# Wait for processes to die
sleep 1

# Start the app in the background using nohup
cd /workspaces/simplechat/application/single_app || exit 1
nohup /app/venv/bin/python app.py > /tmp/flask.log 2>&1 &
FLASK_PID=$!

# Disown the process so it survives shell exit
disown $FLASK_PID 2>/dev/null || true

echo "Flask app started with PID: $FLASK_PID"
echo "Check logs with: tail -f /tmp/flask.log"

# Give it more time to start and initialize
sleep 5

# Verify it's running by checking if the process directory exists
if [ -d "/proc/$FLASK_PID" ]; then
    echo "✓ Flask app is running on port 8000"
    exit 0
else
    echo "⚠ Flask app may have crashed. Checking logs..."
    if [ -f /tmp/flask.log ]; then
        tail -30 /tmp/flask.log
    fi
    # Don't fail the container creation - just warn
    echo "⚠ Flask failed to start, but you can start it manually with: bash /workspaces/simplechat/.devcontainer/start-app.sh"
    exit 0
fi

