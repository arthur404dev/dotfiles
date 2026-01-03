#!/bin/bash
# Test the heimdall startup sequence

echo "=== Testing Heimdall Startup Sequence ==="
echo ""

# Kill any existing processes
echo "Stopping any existing heimdall/quickshell processes..."
killall -q heimdall quickshell qs 2>/dev/null
sleep 2

# Run the initialization script
echo "Running state initialization..."
/home/arthur/dots/wm/.config/hypr/programs/init-heimdall-state.sh
echo ""

# Check the environment
echo "Checking environment..."
/home/arthur/dots/wm/.config/hypr/programs/check-heimdall-env.sh | grep -E "(✓|✗|Running|missing)"
echo ""

# Try to start heimdall manually
echo "Testing manual heimdall start..."
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export HEIMDALL_STATE_DIR="$HOME/.local/state/quickshell/user/generated"
export HEIMDALL_SHARE_DIR="$HOME/.local/share/heimdall"
export QT_QPA_PLATFORM="wayland"

# Try different heimdall commands
echo "Trying: heimdall shell daemon"
timeout 2 heimdall shell daemon 2>&1 | head -5
echo ""

echo "Trying: heimdall daemon"
timeout 2 heimdall daemon 2>&1 | head -5
echo ""

echo "Trying: heimdall --help"
heimdall --help 2>&1 | head -10
echo ""

# Check if quickshell can start with heimdall config
echo "Testing quickshell with heimdall config..."
if command -v qs &> /dev/null; then
    echo "Using qs command..."
    timeout 2 qs -c heimdall 2>&1 | head -5
elif command -v quickshell &> /dev/null; then
    echo "Using quickshell command..."
    timeout 2 quickshell -c heimdall 2>&1 | head -5
else
    echo "No quickshell command found"
fi
echo ""

# Check what's running
echo "Checking running processes after test..."
pgrep -af "heimdall|quickshell" || echo "No processes running"
echo ""

echo "=== Test Complete ==="
echo "Check /tmp/quickshell-startup.log and /tmp/quickshell-startup-errors.log for full startup logs"