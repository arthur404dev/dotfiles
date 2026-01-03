#!/bin/bash
# Wallpaper restoration script for Heimdall/Quickshell
# Restores wallpaper on startup from saved state with enhanced error checking

# Multiple possible state file locations for compatibility
STATE_FILES=(
    "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt"
    "$HOME/.local/share/heimdall/wallpaper_path"
    "$HOME/.local/state/heimdall/wallpaper/path.txt"
)

# Fix the fallback path to match actual location
FALLBACK_WALLPAPER="$HOME/dots/media/Pictures/Wallpapers/Autumn-Alley.jpg"
WALLPAPER_PATH=""

# Function to log with timestamp
log_msg() {
    echo "[$(date +%H:%M:%S)] $1"
}

# Ensure all state directories exist
for state_file in "${STATE_FILES[@]}"; do
    STATE_DIR=$(dirname "$state_file")
    mkdir -p "$STATE_DIR" 2>/dev/null
done

# Try to find wallpaper path from any state file
log_msg "Searching for wallpaper state files..."
for state_file in "${STATE_FILES[@]}"; do
    if [ -f "$state_file" ]; then
        CANDIDATE_PATH=$(cat "$state_file" 2>/dev/null)
        if [ -n "$CANDIDATE_PATH" ] && [ -f "$CANDIDATE_PATH" ]; then
            WALLPAPER_PATH="$CANDIDATE_PATH"
            log_msg "Found valid wallpaper in $state_file: $WALLPAPER_PATH"
            break
        else
            log_msg "State file $state_file exists but wallpaper not found: $CANDIDATE_PATH"
        fi
    fi
done

# If no valid wallpaper found, use fallback
if [ -z "$WALLPAPER_PATH" ]; then
    if [ -f "$FALLBACK_WALLPAPER" ]; then
        WALLPAPER_PATH="$FALLBACK_WALLPAPER"
        log_msg "No saved wallpaper state found, using fallback: $WALLPAPER_PATH"
        
        # Save fallback to state files for next time
        for state_file in "${STATE_FILES[@]}"; do
            echo "$WALLPAPER_PATH" > "$state_file" 2>/dev/null
        done
    else
        log_msg "Error: No wallpaper available (fallback not found: $FALLBACK_WALLPAPER)"
        exit 1
    fi
fi

# Wait for wallpaper daemon to be ready and set wallpaper
WALLPAPER_SET=false
MAX_RETRIES=15
RETRY_COUNT=0

log_msg "Waiting for wallpaper daemon..."

while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$WALLPAPER_SET" = false ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    
    if pgrep -x "swww-daemon" > /dev/null; then
        log_msg "swww-daemon is running (attempt $RETRY_COUNT/$MAX_RETRIES)"
        
        # Initialize swww if needed
        if ! swww query &>/dev/null; then
            log_msg "Initializing swww..."
            swww init 2>/dev/null
            sleep 1
        fi
        
        # Set wallpaper using swww with error checking
        log_msg "Setting wallpaper with swww: $WALLPAPER_PATH"
        if swww img "$WALLPAPER_PATH" --transition-type fade --transition-duration 0.3 2>&1; then
            WALLPAPER_SET=true
            log_msg "Successfully set wallpaper with swww"
            
            # Verify it was actually set
            sleep 0.5
            CURRENT=$(swww query 2>/dev/null | grep -oP 'image: \K.*' | head -1)
            if [ "$CURRENT" = "$WALLPAPER_PATH" ]; then
                log_msg "Wallpaper verified: $CURRENT"
            else
                log_msg "Warning: Wallpaper may not have been set correctly"
                log_msg "Expected: $WALLPAPER_PATH"
                log_msg "Current: $CURRENT"
            fi
        else
            log_msg "Failed to set wallpaper with swww (attempt $RETRY_COUNT)"
        fi
        
    elif pgrep -x "hyprpaper" > /dev/null; then
        log_msg "hyprpaper is running (attempt $RETRY_COUNT/$MAX_RETRIES)"
        
        # Set wallpaper using hyprpaper
        log_msg "Preloading wallpaper in hyprpaper: $WALLPAPER_PATH"
        if hyprctl hyprpaper preload "$WALLPAPER_PATH" 2>&1; then
            log_msg "Setting wallpaper with hyprpaper"
            if hyprctl hyprpaper wallpaper ",$WALLPAPER_PATH" 2>&1; then
                WALLPAPER_SET=true
                log_msg "Successfully set wallpaper with hyprpaper"
            else
                log_msg "Failed to set wallpaper with hyprpaper"
            fi
        else
            log_msg "Failed to preload wallpaper in hyprpaper"
        fi
        
    else
        log_msg "No wallpaper daemon running yet... ($RETRY_COUNT/$MAX_RETRIES)"
        
        # Try to start swww-daemon if it's available but not running
        if [ $RETRY_COUNT -eq 5 ] && command -v swww-daemon &> /dev/null; then
            log_msg "Attempting to start swww-daemon..."
            swww-daemon --format xrgb &
            sleep 1
        fi
    fi
    
    if [ "$WALLPAPER_SET" = false ]; then
        sleep 0.5
    fi
done

if [ "$WALLPAPER_SET" = false ]; then
    log_msg "ERROR: Failed to set wallpaper after $MAX_RETRIES attempts"
    exit 1
fi

# Sync the path to ensure consistency across all state files
log_msg "Syncing wallpaper path to all state files..."
if [ -x ~/.config/hypr/programs/wallpaper-sync.sh ]; then
    ~/.config/hypr/programs/wallpaper-sync.sh "$WALLPAPER_PATH"
else
    # Manual sync if wallpaper-sync.sh is not available
    for state_file in "${STATE_FILES[@]}"; do
        echo "$WALLPAPER_PATH" > "$state_file" 2>/dev/null
    done
fi

log_msg "Wallpaper restoration complete"