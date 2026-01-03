#!/bin/bash
# Startup orchestrator for Heimdall/Quickshell
# Ensures proper initialization sequence with configurable delays and enhanced error checking

LOG_FILE="/tmp/quickshell-startup.log"
ERROR_LOG="/tmp/quickshell-startup-errors.log"
echo "=== Startup Orchestrator Started at $(date) ===" > "$LOG_FILE"
echo "=== Startup Errors Log Started at $(date) ===" > "$ERROR_LOG"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_step() {
    echo "[$(date +%H:%M:%S)] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR $(date +%H:%M:%S)] $1${NC}" | tee -a "$LOG_FILE" | tee -a "$ERROR_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS $(date +%H:%M:%S)] $1${NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING $(date +%H:%M:%S)] $1${NC}" | tee -a "$LOG_FILE"
}

# Function to verify a file exists and is readable
verify_file() {
    local file="$1"
    local description="$2"
    if [ -f "$file" ] && [ -r "$file" ]; then
        log_success "$description exists: $file"
        return 0
    else
        log_error "$description missing or unreadable: $file"
        return 1
    fi
}

# Function to verify a directory exists and is writable
verify_directory() {
    local dir="$1"
    local description="$2"
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        log_success "$description exists and is writable: $dir"
        return 0
    else
        log_warning "$description missing or not writable: $dir"
        mkdir -p "$dir" 2>> "$ERROR_LOG"
        if [ $? -eq 0 ]; then
            log_success "Created $description: $dir"
            return 0
        else
            log_error "Failed to create $description: $dir"
            return 1
        fi
    fi
}

# Function to check if a process is running with retry
check_process_with_retry() {
    local process="$1"
    local max_retries="${2:-5}"
    local delay="${3:-0.5}"
    
    for i in $(seq 1 $max_retries); do
        if pgrep -f "$process" > /dev/null; then
            log_success "$process is running (attempt $i/$max_retries)"
            return 0
        fi
        log_step "Waiting for $process to start... (attempt $i/$max_retries)"
        sleep "$delay"
    done
    
    log_error "$process failed to start after $max_retries attempts"
    return 1
}

# Export required environment variables for heimdall
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export QT_QPA_PLATFORM="wayland"
export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"

# Wait for Wayland display to be ready
log_step "Waiting for Wayland display..."
WAYLAND_WAIT_COUNT=0
while [ -z "$WAYLAND_DISPLAY" ]; do
    sleep 0.1
    WAYLAND_WAIT_COUNT=$((WAYLAND_WAIT_COUNT + 1))
    if [ $WAYLAND_WAIT_COUNT -gt 100 ]; then
        log_error "Wayland display not available after 10 seconds"
        exit 1
    fi
done
log_success "Wayland display ready: $WAYLAND_DISPLAY"

# Wait for Hyprland to be fully initialized
log_step "Waiting for Hyprland to be fully ready..."
sleep 2  # Give Hyprland time to fully initialize

# Check if hyprctl is responsive
HYPR_WAIT_COUNT=0
while ! hyprctl version &>/dev/null; do
    sleep 0.2
    HYPR_WAIT_COUNT=$((HYPR_WAIT_COUNT + 1))
    if [ $HYPR_WAIT_COUNT -gt 50 ]; then
        log_warning "Hyprland not fully responsive after 10 seconds, continuing anyway"
        break
    fi
done
if [ $HYPR_WAIT_COUNT -le 50 ]; then
    log_success "Hyprland is fully responsive"
fi

# Initialize all state files before starting anything
log_step "Initializing Heimdall/Quickshell state files..."
INIT_SCRIPT="$HOME/.config/hypr/programs/init-heimdall-state.sh"
if [ -f "$INIT_SCRIPT" ]; then
    chmod +x "$INIT_SCRIPT"
    if $INIT_SCRIPT >> "$LOG_FILE" 2>> "$ERROR_LOG"; then
        log_success "State initialization completed successfully"
    else
        log_error "State initialization failed - continuing with partial state"
    fi
else
    log_warning "State initialization script not found: $INIT_SCRIPT"
fi

# Start the scheme sync service to handle heimdall-cli color scheme updates
log_step "Starting color scheme sync service..."
SCHEME_SYNC_SCRIPT="$HOME/.config/hypr/programs/scheme-sync.sh"
if [ -f "$SCHEME_SYNC_SCRIPT" ]; then
    chmod +x "$SCHEME_SYNC_SCRIPT"
    # Start in background and detach from this script
    nohup $SCHEME_SYNC_SCRIPT >> "$LOG_FILE" 2>> "$ERROR_LOG" &
    SCHEME_SYNC_PID=$!
    sleep 1
    
    if kill -0 $SCHEME_SYNC_PID 2>/dev/null; then
        log_success "Scheme sync service started (PID: $SCHEME_SYNC_PID)"
    else
        log_warning "Scheme sync service failed to start"
    fi
else
    log_warning "Scheme sync script not found: $SCHEME_SYNC_SCRIPT"
fi

# Ensure all required state directories exist (redundant check)
log_step "Verifying state directories..."

# Primary Quickshell state directory
QUICKSHELL_STATE_DIR="$HOME/.local/state/quickshell/user/generated"
verify_directory "$QUICKSHELL_STATE_DIR" "Quickshell state directory"
verify_directory "$QUICKSHELL_STATE_DIR/wallpaper" "Quickshell wallpaper directory"

# Heimdall share directory
HEIMDALL_SHARE_DIR="$HOME/.local/share/heimdall"
verify_directory "$HEIMDALL_SHARE_DIR" "Heimdall share directory"

# Legacy state directory for compatibility
HEIMDALL_STATE_DIR="$HOME/.local/state/heimdall"
if [ ! -L "$HEIMDALL_STATE_DIR" ] && [ ! -d "$HEIMDALL_STATE_DIR" ]; then
    log_step "Creating heimdall state symlink for compatibility..."
    ln -sf "$QUICKSHELL_STATE_DIR" "$HEIMDALL_STATE_DIR" 2>> "$ERROR_LOG"
    if [ $? -eq 0 ]; then
        log_success "Created heimdall state symlink"
    else
        log_warning "Could not create heimdall state symlink"
    fi
fi

# Ensure wallpaper path files exist with a default if needed
DEFAULT_WALLPAPER="$HOME/dots/media/Pictures/Wallpapers/Autumn-Alley.jpg"
WALLPAPER_PATHS=(
    "$QUICKSHELL_STATE_DIR/wallpaper/path.txt"
    "$HEIMDALL_SHARE_DIR/wallpaper_path"
)

for path_file in "${WALLPAPER_PATHS[@]}"; do
    if [ ! -f "$path_file" ]; then
        if [ -f "$DEFAULT_WALLPAPER" ]; then
            echo "$DEFAULT_WALLPAPER" > "$path_file"
            log_success "Created wallpaper path file: $path_file"
        else
            log_error "Default wallpaper not found: $DEFAULT_WALLPAPER"
        fi
    else
        CURRENT_WALLPAPER=$(cat "$path_file" 2>/dev/null)
        if [ -f "$CURRENT_WALLPAPER" ]; then
            log_success "Wallpaper path file exists with valid wallpaper: $path_file"
        else
            log_warning "Wallpaper in $path_file not found: $CURRENT_WALLPAPER"
            if [ -f "$DEFAULT_WALLPAPER" ]; then
                echo "$DEFAULT_WALLPAPER" > "$path_file"
                log_success "Reset to default wallpaper in $path_file"
            fi
        fi
    fi
done

# Check for color scheme files
COLOR_FILES=(
    "$QUICKSHELL_STATE_DIR/scheme.json"
    "$QUICKSHELL_STATE_DIR/colors.json"
    "$QUICKSHELL_STATE_DIR/color.txt"
)

for color_file in "${COLOR_FILES[@]}"; do
    if [ -f "$color_file" ]; then
        log_success "Color file exists: $color_file"
    else
        log_warning "Color file missing: $color_file"
    fi
done

# Ensure scheme.json exists in all required locations
if [ ! -f "$QUICKSHELL_STATE_DIR/scheme.json" ]; then
    if [ -f "$QUICKSHELL_STATE_DIR/colors.json" ]; then
        cp "$QUICKSHELL_STATE_DIR/colors.json" "$QUICKSHELL_STATE_DIR/scheme.json"
        log_success "Created scheme.json from colors.json"
    else
        log_error "No color scheme files found to create scheme.json"
    fi
fi

if [ ! -f "$HEIMDALL_SHARE_DIR/scheme.json" ]; then
    if [ -f "$QUICKSHELL_STATE_DIR/scheme.json" ]; then
        cp "$QUICKSHELL_STATE_DIR/scheme.json" "$HEIMDALL_SHARE_DIR/scheme.json"
        log_success "Copied scheme.json to heimdall share directory"
    fi
fi

# Step 1: Initialize display (immediate)
log_step "Initializing display..."
sleep 0.5

# Step 2: Start wallpaper daemon with enhanced error checking
log_step "Starting wallpaper daemon..."
WALLPAPER_DAEMON=""

if command -v swww-daemon &> /dev/null; then
    if ! pgrep -x "swww-daemon" > /dev/null; then
        log_step "Starting swww-daemon..."
        swww-daemon --format xrgb >> "$LOG_FILE" 2>> "$ERROR_LOG" &
        SWWW_PID=$!
        sleep 1
        
        if kill -0 $SWWW_PID 2>/dev/null; then
            log_success "swww-daemon started successfully (PID: $SWWW_PID)"
            WALLPAPER_DAEMON="swww"
        else
            log_error "swww-daemon failed to start"
            # Check error log for details
            tail -n 5 "$ERROR_LOG" | while read line; do
                log_error "  $line"
            done
        fi
    else
        log_success "swww-daemon already running"
        WALLPAPER_DAEMON="swww"
    fi
elif command -v hyprpaper &> /dev/null; then
    if ! pgrep -x "hyprpaper" > /dev/null; then
        log_step "Starting hyprpaper..."
        hyprpaper >> "$LOG_FILE" 2>> "$ERROR_LOG" &
        HYPRPAPER_PID=$!
        sleep 1
        
        if kill -0 $HYPRPAPER_PID 2>/dev/null; then
            log_success "hyprpaper started successfully (PID: $HYPRPAPER_PID)"
            WALLPAPER_DAEMON="hyprpaper"
        else
            log_error "hyprpaper failed to start"
        fi
    else
        log_success "hyprpaper already running"
        WALLPAPER_DAEMON="hyprpaper"
    fi
else
    log_error "No wallpaper daemon (swww-daemon or hyprpaper) found!"
fi

# Step 3: Restore wallpaper with verification
log_step "Restoring wallpaper..."
if [ -n "$WALLPAPER_DAEMON" ]; then
    RESTORE_OUTPUT=$( ~/.config/hypr/programs/restore-wallpaper.sh 2>&1 )
    RESTORE_EXIT_CODE=$?
    echo "$RESTORE_OUTPUT" >> "$LOG_FILE"
    
    if [ $RESTORE_EXIT_CODE -eq 0 ]; then
        log_success "Wallpaper restoration completed"
        
        # Verify wallpaper was actually set
        sleep 1
        if [ "$WALLPAPER_DAEMON" = "swww" ]; then
            CURRENT_WALLPAPER=$(swww query 2>/dev/null | grep -oP 'image: \K.*' | head -1)
            if [ -n "$CURRENT_WALLPAPER" ]; then
                log_success "Wallpaper verified: $CURRENT_WALLPAPER"
            else
                log_warning "Could not verify wallpaper was set"
            fi
        fi
    else
        log_error "Wallpaper restoration failed with exit code $RESTORE_EXIT_CODE"
    fi
else
    log_error "Cannot restore wallpaper - no daemon running"
fi

# Step 4: Start Quickshell with Heimdall configuration
log_step "Starting Quickshell components..."

# Check if quickshell command exists
if ! command -v quickshell &> /dev/null && ! command -v qs &> /dev/null; then
    log_error "quickshell/qs command not found! Please ensure quickshell is installed."
    exit 1
fi

# Kill any existing quickshell processes first to ensure clean start
if pgrep -f "quickshell" > /dev/null; then
    log_step "Stopping existing Quickshell processes..."
    killall -q quickshell qs 2>/dev/null
    sleep 1
fi

# Start Quickshell with heimdall configuration
QUICKSHELL_CONFIG="heimdall"
QUICKSHELL_CONFIG_PATH="$HOME/.config/quickshell/$QUICKSHELL_CONFIG"

if [ ! -d "$QUICKSHELL_CONFIG_PATH" ]; then
    log_error "Quickshell config directory not found: $QUICKSHELL_CONFIG_PATH"
    # Try to find alternative configs
    log_step "Available configs:"
    ls -la "$HOME/.config/quickshell/" 2>/dev/null | grep "^d" | awk '{print "  - " $NF}'
else
    log_step "Starting Quickshell with config: $QUICKSHELL_CONFIG"
    
    # Export required environment for quickshell
    export QS_CONFIG_PATH="$QUICKSHELL_CONFIG_PATH"
    export QUICKSHELL_CONFIG_PATH="$QUICKSHELL_CONFIG_PATH"
    
    # Check which command is available
    if command -v qs &> /dev/null; then
        QUICKSHELL_CMD="qs"
    elif command -v quickshell &> /dev/null; then
        QUICKSHELL_CMD="quickshell"
    else
        log_error "Neither qs nor quickshell command found!"
        QUICKSHELL_CMD=""
    fi
    
    if [ -n "$QUICKSHELL_CMD" ]; then
        # Start quickshell with the heimdall configuration
        # Try with -c flag first
        $QUICKSHELL_CMD -c "$QUICKSHELL_CONFIG" >> "$LOG_FILE" 2>> "$ERROR_LOG" &
        QUICKSHELL_PID=$!
    
    # Wait for quickshell to start
    sleep 3
    
    # Verify quickshell started
    if kill -0 $QUICKSHELL_PID 2>/dev/null && pgrep -f "quickshell" > /dev/null; then
        log_success "Quickshell started successfully (PID: $QUICKSHELL_PID)"
        
        # List all quickshell processes for debugging
        log_step "Active Quickshell processes:"
        pgrep -af "quickshell" | while read line; do
            log_step "  $line"
        done
        
        # Test IPC communication
        if qs -c "$QUICKSHELL_CONFIG" ipc call TEST_ALIVE &>/dev/null; then
            log_success "Quickshell IPC is responding"
        else
            log_warning "Quickshell IPC not responding yet (may still be initializing)"
        fi
    else
        log_error "Quickshell failed to start"
        
        # Check error log for details
        if [ -s "$ERROR_LOG" ]; then
            log_error "Recent errors:"
            tail -n 10 "$ERROR_LOG" | while read line; do
                [ -n "$line" ] && log_error "  $line"
            done
        fi
        
        # Try alternative start method
        log_step "Attempting alternative start method..."
        if [ -n "$QUICKSHELL_CMD" ]; then
            # Try with --config flag
            $QUICKSHELL_CMD --config "$QUICKSHELL_CONFIG_PATH" >> "$LOG_FILE" 2>> "$ERROR_LOG" &
            QUICKSHELL_PID=$!
            sleep 2
            
            if kill -0 $QUICKSHELL_PID 2>/dev/null; then
                log_success "Quickshell started with --config flag (PID: $QUICKSHELL_PID)"
            else
                # Try without any flags (if default config is set)
                log_step "Trying to start quickshell without config flag..."
                cd "$QUICKSHELL_CONFIG_PATH" && $QUICKSHELL_CMD >> "$LOG_FILE" 2>> "$ERROR_LOG" &
                QUICKSHELL_PID=$!
                sleep 2
                
                if kill -0 $QUICKSHELL_PID 2>/dev/null; then
                    log_success "Quickshell started from config directory (PID: $QUICKSHELL_PID)"
                else
                    log_error "All quickshell start methods failed"
                fi
            fi
        fi
    fi
    else
        log_error "No quickshell command available to start"
    fi
fi

# Check if heimdall command exists for additional services
if command -v heimdall &> /dev/null; then
    log_step "Checking heimdall services..."
    
    # Get heimdall version
    HEIMDALL_VERSION=$(heimdall --version 2>&1 || echo "unknown")
    log_step "Heimdall version: $HEIMDALL_VERSION"
    
    # Start heimdall shell daemon if needed
    if ! pgrep -f "heimdall.*daemon" > /dev/null; then
        log_step "Starting heimdall shell daemon..."
        
        # Export environment for heimdall
        export HEIMDALL_STATE_DIR="$HOME/.local/state/quickshell/user/generated"
        export HEIMDALL_SHARE_DIR="$HOME/.local/share/heimdall"
        
        # Try the correct daemon command format
        if heimdall shell daemon >> "$LOG_FILE" 2>> "$ERROR_LOG" &
        then
            HEIMDALL_SHELL_PID=$!
            sleep 2
            
            if kill -0 $HEIMDALL_SHELL_PID 2>/dev/null; then
                log_success "heimdall shell daemon started (PID: $HEIMDALL_SHELL_PID)"
            else
                # Try alternative format
                heimdall daemon >> "$LOG_FILE" 2>> "$ERROR_LOG" &
                HEIMDALL_SHELL_PID=$!
                sleep 2
                
                if kill -0 $HEIMDALL_SHELL_PID 2>/dev/null; then
                    log_success "heimdall daemon started with alternative command (PID: $HEIMDALL_SHELL_PID)"
                else
                    log_warning "heimdall daemon failed to start (may not be required)"
                fi
            fi
        else
            log_warning "heimdall shell daemon command not available"
        fi
    else
        log_success "heimdall daemon already running"
    fi
    
    # Start heimdall pip if needed
    if ! pgrep -f "heimdall pip" > /dev/null; then
        log_step "Starting heimdall pip..."
        
        heimdall pip >> "$LOG_FILE" 2>> "$ERROR_LOG" &
        HEIMDALL_PIP_PID=$!
        
        sleep 1
        
        if kill -0 $HEIMDALL_PIP_PID 2>/dev/null && pgrep -f "heimdall pip" > /dev/null; then
            log_success "heimdall pip started (PID: $HEIMDALL_PIP_PID)"
        else
            log_warning "heimdall pip failed to start (may not be required)"
        fi
    else
        log_success "heimdall pip already running"
    fi
else
    log_warning "heimdall command not found - some features may be unavailable"
fi

# Step 5: Final state verification
log_step "Performing final state verification..."

# Check critical state files
CRITICAL_FILES=(
    "$QUICKSHELL_STATE_DIR/wallpaper/path.txt"
    "$HEIMDALL_SHARE_DIR/wallpaper_path"
)

ALL_GOOD=true
for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "Critical file missing after startup: $file"
        ALL_GOOD=false
    fi
done

if [ "$ALL_GOOD" = true ]; then
    log_success "All critical state files verified"
else
    log_error "Some critical state files are missing - Quickshell may not work properly"
fi

# Step 6: Start Docker Desktop if installed (delayed)
if command -v docker-desktop &> /dev/null; then
    sleep 2
    log_step "Starting Docker Desktop..."
    # Start Docker Desktop without systemd manipulation
    docker-desktop >> "$LOG_FILE" 2>> "$ERROR_LOG" &
    log_step "Docker Desktop launch initiated"
fi

# Final summary
echo "=== Startup Summary ===" >> "$LOG_FILE"
echo "Wallpaper Daemon: $WALLPAPER_DAEMON" >> "$LOG_FILE"
echo "Heimdall Shell: $(pgrep -f 'heimdall shell' > /dev/null && echo 'Running' || echo 'Not Running')" >> "$LOG_FILE"
echo "Heimdall PIP: $(pgrep -f 'heimdall pip' > /dev/null && echo 'Running' || echo 'Not Running')" >> "$LOG_FILE"
echo "Quickshell: $(pgrep -f 'quickshell' > /dev/null && echo 'Running' || echo 'Not Running')" >> "$LOG_FILE"

# Check for any errors
ERROR_COUNT=$(grep -c "ERROR" "$ERROR_LOG" 2>/dev/null || echo "0")
if [ "$ERROR_COUNT" -gt 0 ]; then
    log_warning "Startup completed with $ERROR_COUNT errors - check $ERROR_LOG for details"
else
    log_success "Startup sequence completed successfully"
fi

echo "=== Startup Orchestrator Finished at $(date) ===" >> "$LOG_FILE"