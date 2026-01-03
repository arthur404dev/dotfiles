#!/bin/bash
# Check environment differences for heimdall between manual and startup runs

echo "=== Heimdall Environment Check ==="
echo "Date: $(date)"
echo ""

# Check current environment
echo "=== Current Environment ==="
echo "USER: $USER"
echo "HOME: $HOME"
echo "PATH: $PATH"
echo "WAYLAND_DISPLAY: $WAYLAND_DISPLAY"
echo "XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
echo "XDG_DATA_HOME: ${XDG_DATA_HOME:-not set}"
echo "XDG_STATE_HOME: ${XDG_STATE_HOME:-not set}"
echo "XDG_CONFIG_HOME: ${XDG_CONFIG_HOME:-not set}"
echo "QT_QPA_PLATFORM: ${QT_QPA_PLATFORM:-not set}"
echo "QT_WAYLAND_DISABLE_WINDOWDECORATION: ${QT_WAYLAND_DISABLE_WINDOWDECORATION:-not set}"
echo ""

# Check if running in terminal or startup context
if [ -t 0 ]; then
    echo "Running in: Interactive terminal"
else
    echo "Running in: Non-interactive (startup/script)"
fi
echo ""

# Check process tree
echo "=== Process Context ==="
echo "Parent PID: $PPID"
echo "Parent process: $(ps -p $PPID -o comm= 2>/dev/null || echo "unknown")"
echo ""

# Check heimdall binary
echo "=== Heimdall Binary ==="
if command -v heimdall &> /dev/null; then
    echo "heimdall found at: $(which heimdall)"
    echo "heimdall version: $(heimdall --version 2>&1 || echo "error getting version")"
    
    # Check if it's a symlink
    HEIMDALL_PATH=$(which heimdall)
    if [ -L "$HEIMDALL_PATH" ]; then
        echo "heimdall is a symlink to: $(readlink -f "$HEIMDALL_PATH")"
    fi
else
    echo "heimdall command not found in PATH"
fi
echo ""

# Check quickshell binary
echo "=== Quickshell Binary ==="
if command -v quickshell &> /dev/null; then
    echo "quickshell found at: $(which quickshell)"
elif command -v qs &> /dev/null; then
    echo "qs found at: $(which qs)"
    if [ -L "$(which qs)" ]; then
        echo "qs is a symlink to: $(readlink -f "$(which qs)")"
    fi
else
    echo "quickshell/qs command not found in PATH"
fi
echo ""

# Check required directories
echo "=== Required Directories ==="
DIRS=(
    "$HOME/.local/state/quickshell/user/generated"
    "$HOME/.local/share/heimdall"
    "$HOME/.config/quickshell/heimdall"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✓ $dir exists"
        # Check permissions
        PERMS=$(stat -c "%a" "$dir")
        echo "  Permissions: $PERMS"
    else
        echo "✗ $dir missing"
    fi
done
echo ""

# Check required files
echo "=== Required Files ==="
FILES=(
    "$HOME/.local/state/quickshell/user/generated/scheme.json"
    "$HOME/.local/state/quickshell/user/generated/colors.json"
    "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt"
    "$HOME/.local/share/heimdall/wallpaper_path"
    "$HOME/.local/share/heimdall/scheme.json"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
        SIZE=$(stat -c "%s" "$file")
        echo "  Size: $SIZE bytes"
    elif [ -L "$file" ]; then
        echo "↗ $file is a symlink to: $(readlink -f "$file")"
        if [ -f "$(readlink -f "$file")" ]; then
            echo "  Target exists"
        else
            echo "  Target missing!"
        fi
    else
        echo "✗ $file missing"
    fi
done
echo ""

# Check running processes
echo "=== Running Processes ==="
if pgrep -f "heimdall" > /dev/null; then
    echo "heimdall processes:"
    pgrep -af "heimdall" | sed 's/^/  /'
else
    echo "No heimdall processes running"
fi

if pgrep -f "quickshell" > /dev/null; then
    echo "quickshell processes:"
    pgrep -af "quickshell" | sed 's/^/  /'
else
    echo "No quickshell processes running"
fi
echo ""

# Check for missing binaries mentioned in logs
echo "=== Checking for Missing Binaries ==="
MISSING_BINS=(
    "/usr/lib/heimdall/beat_detector"
    "/usr/lib/quickshell/beat_detector"
)

for bin in "${MISSING_BINS[@]}"; do
    if [ -f "$bin" ]; then
        echo "✓ $bin exists"
    else
        echo "✗ $bin missing (may not be required)"
    fi
done
echo ""

# Try to start heimdall manually if not running
if ! pgrep -f "heimdall" > /dev/null; then
    echo "=== Attempting Manual Start ==="
    echo "Trying: heimdall shell daemon"
    
    # Set environment
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
    export HEIMDALL_STATE_DIR="$HOME/.local/state/quickshell/user/generated"
    export HEIMDALL_SHARE_DIR="$HOME/.local/share/heimdall"
    
    timeout 5 heimdall shell daemon 2>&1 | head -20
    
    if [ ${PIPESTATUS[0]} -eq 124 ]; then
        echo "Command timed out (might be running successfully in background)"
    fi
else
    echo "=== Heimdall Already Running ==="
fi

echo ""
echo "=== End of Environment Check ==="