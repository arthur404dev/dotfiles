#!/bin/bash
# Wallpaper synchronization script for Heimdall/Quickshell
# Ensures wallpaper path is written to all required locations

WALLPAPER_PATH="$1"

if [ -z "$WALLPAPER_PATH" ]; then
    echo "Usage: $0 <wallpaper-path>"
    exit 1
fi

# Ensure the wallpaper file exists
if [ ! -f "$WALLPAPER_PATH" ]; then
    echo "Error: Wallpaper file not found: $WALLPAPER_PATH"
    exit 1
fi

# Function to log with timestamp
log_msg() {
    echo "[$(date +%H:%M:%S)] $1"
}

# All locations where wallpaper path should be stored
STATE_LOCATIONS=(
    "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt"
    "$HOME/.local/share/heimdall/wallpaper_path"
    "$HOME/.local/state/heimdall/wallpaper/path.txt"
)

# Create all necessary directories and write wallpaper path
log_msg "Synchronizing wallpaper path: $WALLPAPER_PATH"
SYNC_SUCCESS=true

for state_file in "${STATE_LOCATIONS[@]}"; do
    STATE_DIR=$(dirname "$state_file")
    
    # Create directory if it doesn't exist
    if ! mkdir -p "$STATE_DIR" 2>/dev/null; then
        log_msg "Warning: Could not create directory: $STATE_DIR"
        SYNC_SUCCESS=false
        continue
    fi
    
    # Write the wallpaper path
    if echo "$WALLPAPER_PATH" > "$state_file" 2>/dev/null; then
        log_msg "✓ Updated: $state_file"
    else
        log_msg "✗ Failed to update: $state_file"
        SYNC_SUCCESS=false
    fi
done

# Create compatibility symlinks if needed
SYMLINKS=(
    "$HOME/.local/state/heimdall:$HOME/.local/state/quickshell/user/generated"
)

for symlink_pair in "${SYMLINKS[@]}"; do
    IFS=':' read -r link target <<< "$symlink_pair"
    
    if [ ! -e "$link" ]; then
        if ln -sf "$target" "$link" 2>/dev/null; then
            log_msg "✓ Created symlink: $link -> $target"
        else
            log_msg "✗ Could not create symlink: $link"
        fi
    elif [ -L "$link" ]; then
        CURRENT_TARGET=$(readlink -f "$link")
        if [ "$CURRENT_TARGET" != "$(readlink -f "$target")" ]; then
            log_msg "ℹ Existing symlink points elsewhere: $link -> $CURRENT_TARGET"
        fi
    fi
done

# Also update the color scheme if heimdall is available
if command -v heimdall &> /dev/null && [ "$SYNC_SUCCESS" = true ]; then
    log_msg "Generating color scheme from wallpaper..."
    if heimdall scheme generate "$WALLPAPER_PATH" &>/dev/null; then
        log_msg "✓ Color scheme generated"
    else
        log_msg "ℹ Could not generate color scheme (heimdall may not be running)"
    fi
fi

if [ "$SYNC_SUCCESS" = true ]; then
    log_msg "✓ Wallpaper path synchronized successfully"
else
    log_msg "⚠ Wallpaper path synchronized with warnings"
    exit 1
fi