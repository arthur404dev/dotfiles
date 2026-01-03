#!/bin/bash
# Manual restart script for Heimdall/Quickshell
# Use this to restart the shell when testing or after configuration changes

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Restarting Heimdall/Quickshell ===${NC}"

# Function to log messages
log_msg() {
    echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +%H:%M:%S)]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} $1"
}

# Step 1: Kill existing processes
log_msg "Stopping existing processes..."

# Kill quickshell
if pgrep -f "quickshell" > /dev/null; then
    killall -q quickshell qs 2>/dev/null
    log_msg "Stopped Quickshell"
fi

# Kill heimdall services
if pgrep -f "heimdall" > /dev/null; then
    killall -q heimdall 2>/dev/null
    log_msg "Stopped Heimdall services"
fi

# Wait for processes to terminate
sleep 2

# Step 2: Initialize all state files
log_msg "Initializing state files..."

# Run the comprehensive initialization script
INIT_SCRIPT="$HOME/.config/hypr/programs/init-heimdall-state.sh"
if [ -f "$INIT_SCRIPT" ]; then
    if $INIT_SCRIPT >/dev/null 2>&1; then
        log_msg "State initialization completed successfully"
    else
        log_warning "State initialization had some issues but continuing..."
    fi
else
    log_warning "State initialization script not found, using fallback method"
    
    STATE_DIR="$HOME/.local/state/quickshell/user/generated"
    WALLPAPER_FILE="$STATE_DIR/wallpaper/path.txt"
    HEIMDALL_SHARE="$HOME/.local/share/heimdall/wallpaper_path"
    
    # Ensure directories exist
    mkdir -p "$STATE_DIR/wallpaper" 2>/dev/null
    mkdir -p "$HOME/.local/share/heimdall" 2>/dev/null
    
    # Check wallpaper state
    if [ ! -f "$WALLPAPER_FILE" ]; then
        DEFAULT_WALLPAPER="$HOME/dots/media/Pictures/Wallpapers/Autumn-Alley.jpg"
        if [ -f "$DEFAULT_WALLPAPER" ]; then
            echo "$DEFAULT_WALLPAPER" > "$WALLPAPER_FILE"
            echo "$DEFAULT_WALLPAPER" > "$HEIMDALL_SHARE"
            log_msg "Created wallpaper state with default"
        fi
    fi
fi

# Export environment variables
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export QT_QPA_PLATFORM="wayland"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"

# Step 3: Ensure wallpaper daemon is running
log_msg "Checking wallpaper daemon..."

if ! pgrep -x "swww-daemon" > /dev/null && ! pgrep -x "hyprpaper" > /dev/null; then
    log_msg "Starting swww-daemon..."
    swww-daemon --format xrgb &
    sleep 1
    
    # Restore wallpaper
    if [ -f "$WALLPAPER_FILE" ]; then
        WALLPAPER=$(cat "$WALLPAPER_FILE")
        if [ -f "$WALLPAPER" ]; then
            swww img "$WALLPAPER" --transition-type fade --transition-duration 0.3
            log_msg "Wallpaper restored"
        fi
    fi
else
    log_msg "Wallpaper daemon already running"
fi

# Step 4: Start Quickshell
log_msg "Starting Quickshell..."

QUICKSHELL_CONFIG="heimdall"
QUICKSHELL_CONFIG_PATH="$HOME/.config/quickshell/$QUICKSHELL_CONFIG"

if [ ! -d "$QUICKSHELL_CONFIG_PATH" ]; then
    log_error "Config not found: $QUICKSHELL_CONFIG_PATH"
    echo -e "${CYAN}Available configs:${NC}"
    ls -la "$HOME/.config/quickshell/" | grep "^d" | awk '{print "  - " $NF}'
    exit 1
fi

# Start quickshell
qs -c "$QUICKSHELL_CONFIG" &
QUICKSHELL_PID=$!

log_msg "Quickshell started with PID: $QUICKSHELL_PID"

# Wait for initialization
sleep 3

# Step 5: Verify startup
log_msg "Verifying startup..."

if pgrep -f "quickshell" > /dev/null; then
    log_msg "✓ Quickshell is running"
    
    # Test IPC
    if qs -c "$QUICKSHELL_CONFIG" ipc call TEST_ALIVE &>/dev/null; then
        log_msg "✓ Quickshell IPC is responding"
    else
        log_warning "⚠ Quickshell IPC not responding (may still be initializing)"
    fi
else
    log_error "✗ Quickshell is not running"
fi

# Step 6: Start heimdall services if available
if command -v heimdall &> /dev/null; then
    log_msg "Starting heimdall services..."
    
    # Set heimdall environment
    export HEIMDALL_STATE_DIR="$HOME/.local/state/quickshell/user/generated"
    export HEIMDALL_SHARE_DIR="$HOME/.local/share/heimdall"
    
    # Try to start shell daemon with correct command
    if heimdall shell daemon &>/dev/null &
    then
        sleep 1
        log_msg "Started heimdall shell daemon"
    elif heimdall daemon &>/dev/null &
    then
        sleep 1
        log_msg "Started heimdall daemon (alternative command)"
    else
        log_warning "Could not start heimdall daemon (may not be required)"
    fi
    
    # Start pip
    if heimdall pip &>/dev/null &
    then
        sleep 1
        log_msg "Started heimdall pip"
    else
        log_warning "Could not start heimdall pip (may not be required)"
    fi
    
    if pgrep -f "heimdall" > /dev/null; then
        log_msg "✓ Heimdall services started"
    else
        log_warning "⚠ Heimdall services not running (may be integrated into quickshell)"
    fi
fi

# Final status
echo -e "\n${CYAN}=== Status ===${NC}"
echo -e "Quickshell: $(pgrep -f 'quickshell' > /dev/null && echo -e '${GREEN}Running${NC}' || echo -e '${RED}Not Running${NC}')"
echo -e "Wallpaper Daemon: $(pgrep -x 'swww-daemon' > /dev/null && echo -e '${GREEN}swww running${NC}' || (pgrep -x 'hyprpaper' > /dev/null && echo -e '${GREEN}hyprpaper running${NC}' || echo -e '${RED}Not Running${NC}'))"
echo -e "Heimdall Shell: $(pgrep -f 'heimdall shell' > /dev/null && echo -e '${GREEN}Running${NC}' || echo -e '${YELLOW}Not Running${NC}')"
echo -e "Heimdall PIP: $(pgrep -f 'heimdall pip' > /dev/null && echo -e '${GREEN}Running${NC}' || echo -e '${YELLOW}Not Running${NC}')"

echo -e "\n${CYAN}Logs available at:${NC}"
echo "  - /tmp/quickshell-startup.log"
echo "  - /tmp/quickshell-startup-errors.log"

echo -e "\n${GREEN}Restart complete!${NC}"