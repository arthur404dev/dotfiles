#!/bin/bash
# Scheme sync script - watches for heimdall-cli changes and converts to Quickshell format
# This bridges the gap between heimdall-cli's current_scheme.json and Quickshell's expected format

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[SCHEME-SYNC]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SCHEME-SYNC]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[SCHEME-SYNC]${NC} $1"
}

log_error() {
    echo -e "${RED}[SCHEME-SYNC]${NC} $1"
}

# Configuration
HEIMDALL_CLI_SCHEME="/home/arthur/.local/state/current_scheme.json"
HEIMDALL_CLI_ALT="/home/arthur/.config/heimdall-cli/current_scheme.json"
QUICKSHELL_STATE_DIR="/home/arthur/.local/state/quickshell/user/generated"
HEIMDALL_SHARE_DIR="/home/arthur/.local/share/heimdall"

# Ensure directories exist
mkdir -p "$QUICKSHELL_STATE_DIR"
mkdir -p "$HEIMDALL_SHARE_DIR"

# Function to convert heimdall-cli format to Quickshell format
convert_scheme() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -f "$input_file" ]; then
        log_error "Input file not found: $input_file"
        return 1
    fi
    
    # Use Python to convert the complex format to simple format
    python3 -c "
import json
import sys

try:
    with open('$input_file', 'r') as f:
        data = json.load(f)
    
    # Extract the scheme information
    output = {
        'name': data.get('name', 'custom'),
        'flavour': data.get('flavour', ''),
        'mode': data.get('mode', 'dark'),
        'variant': data.get('variant', 'dark')
    }
    
    # Convert colors - extract just the hex values
    colours = {}
    color_map = data.get('colors', {})
    
    # Map heimdall-cli color names to Quickshell M3 color names
    # This mapping is based on Material Design 3 color system
    color_mappings = {
        'background': 'background',
        'foreground': 'onBackground',
        'color0': 'surfaceContainerLowest',  # black
        'color1': 'error',                    # red
        'color2': 'tertiary',                 # green
        'color3': 'secondary',                # yellow
        'color4': 'primary',                  # blue
        'color5': 'primary_paletteKeyColor',  # magenta
        'color6': 'tertiary_paletteKeyColor', # cyan
        'color7': 'surface',                  # white
        'color8': 'surfaceVariant',           # bright black
        'color9': 'errorContainer',           # bright red
        'color10': 'tertiaryContainer',       # bright green
        'color11': 'secondaryContainer',      # bright yellow
        'color12': 'primaryContainer',        # bright blue
        'color13': 'inversePrimary',          # bright magenta
        'color14': 'inverseSurface',          # bright cyan
        'color15': 'onSurface',               # bright white
    }
    
    # Also handle terminal color names if present
    terminal_mappings = {
        'black': 'surfaceContainerLowest',
        'red': 'error',
        'green': 'tertiary',
        'yellow': 'secondary',
        'blue': 'primary',
        'magenta': 'primary_paletteKeyColor',
        'cyan': 'tertiary_paletteKeyColor',
        'white': 'surface',
        'bright_black': 'surfaceVariant',
        'bright_red': 'errorContainer',
        'bright_green': 'tertiaryContainer',
        'bright_yellow': 'secondaryContainer',
        'bright_blue': 'primaryContainer',
        'bright_magenta': 'inversePrimary',
        'bright_cyan': 'inverseSurface',
        'bright_white': 'onSurface',
    }
    
    # Process colors
    for key, value in color_map.items():
        # Extract hex value
        hex_value = None
        if isinstance(value, dict) and 'hex' in value:
            hex_value = value['hex'].lstrip('#')
        elif isinstance(value, str):
            hex_value = value.lstrip('#')
        
        if hex_value:
            # Map to M3 color name if possible
            if key in color_mappings:
                colours[color_mappings[key]] = hex_value
            elif key in terminal_mappings:
                colours[terminal_mappings[key]] = hex_value
            else:
                # Keep original name for unmapped colors
                colours[key] = hex_value
    
    # Add additional M3 colors based on the primary colors
    # These are approximations for a complete M3 palette
    if 'primary' in colours:
        primary = colours['primary']
        # Generate related colors if not present
        if 'onPrimary' not in colours:
            colours['onPrimary'] = 'FFFFFF' if output['mode'] == 'dark' else '000000'
        if 'primaryContainer' not in colours and 'color12' in color_map:
            if isinstance(color_map['color12'], dict):
                colours['primaryContainer'] = color_map['color12']['hex'].lstrip('#')
        if 'onPrimaryContainer' not in colours:
            colours['onPrimaryContainer'] = 'E5DEFF'
    
    # Ensure we have all critical M3 colors
    # Fill in missing colors with sensible defaults
    default_colors = {
        'primary_paletteKeyColor': '7870AB',
        'secondary_paletteKeyColor': '78748A',
        'tertiary_paletteKeyColor': '976A7D',
        'neutral_paletteKeyColor': '79767D',
        'neutral_variant_paletteKeyColor': '797680',
        'background': '141318',
        'onBackground': 'E5E1E9',
        'surface': '141318',
        'surfaceDim': '141318',
        'surfaceBright': '3A383E',
        'surfaceContainerLowest': '0E0D13',
        'surfaceContainerLow': '1C1B20',
        'surfaceContainer': '201F25',
        'surfaceContainerHigh': '2B292F',
        'surfaceContainerHighest': '35343A',
        'onSurface': 'E5E1E9',
        'surfaceVariant': '48454E',
        'onSurfaceVariant': 'C9C5D0',
        'inverseSurface': 'E5E1E9',
        'inverseOnSurface': '312F36',
        'outline': '938F99',
        'outlineVariant': '48454E',
        'shadow': '000000',
        'scrim': '000000',
        'surfaceTint': 'C8BFFF',
        'primary': 'C8BFFF',
        'onPrimary': '30285F',
        'primaryContainer': '473F77',
        'onPrimaryContainer': 'E5DEFF',
        'inversePrimary': '5F5791',
        'secondary': 'C9C3DC',
        'onSecondary': '312E41',
        'secondaryContainer': '484459',
        'onSecondaryContainer': 'E5DFF9',
        'tertiary': 'ECB8CD',
        'onTertiary': '482536',
        'tertiaryContainer': 'B38397',
        'onTertiaryContainer': '000000',
        'error': 'EA8DC1',
        'onError': '690005',
        'errorContainer': '93000A',
        'onErrorContainer': 'FFDAD6',
        'primaryFixed': 'E5DEFF',
        'primaryFixedDim': 'C8BFFF',
        'onPrimaryFixed': '1B1149',
        'onPrimaryFixedVariant': '473F77',
        'secondaryFixed': 'E5DFF9',
        'secondaryFixedDim': 'C9C3DC',
        'onSecondaryFixed': '1C192B',
        'onSecondaryFixedVariant': '484459',
        'tertiaryFixed': 'FFD8E7',
        'tertiaryFixedDim': 'ECB8CD',
        'onTertiaryFixed': '301121',
        'onTertiaryFixedVariant': '613B4C'
    }
    
    # Fill in missing colors
    for key, value in default_colors.items():
        if key not in colours:
            colours[key] = value
    
    output['colours'] = colours
    
    # Write the output
    with open('$output_file', 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f'Successfully converted scheme to {output_file}')
    
except Exception as e:
    print(f'Error converting scheme: {e}', file=sys.stderr)
    sys.exit(1)
"
    
    return $?
}

# Function to sync scheme files
sync_schemes() {
    local source_file=""
    
    # Find the source file
    if [ -f "$HEIMDALL_CLI_SCHEME" ]; then
        source_file="$HEIMDALL_CLI_SCHEME"
    elif [ -f "$HEIMDALL_CLI_ALT" ]; then
        source_file="$HEIMDALL_CLI_ALT"
    else
        log_warning "No heimdall-cli scheme file found"
        return 1
    fi
    
    log_info "Converting scheme from: $source_file"
    
    # Convert and save to multiple locations
    local temp_file="/tmp/converted_scheme_$$.json"
    
    if convert_scheme "$source_file" "$temp_file"; then
        # Copy to all required locations
        cp "$temp_file" "$QUICKSHELL_STATE_DIR/scheme.json"
        cp "$temp_file" "$QUICKSHELL_STATE_DIR/colors.json"
        cp "$temp_file" "$HEIMDALL_SHARE_DIR/scheme.json"
        cp "$temp_file" "$HEIMDALL_SHARE_DIR/colors.json"
        
        # Also update the heimdall config directory if it exists
        if [ -d "/home/arthur/.config/quickshell/heimdall/config" ]; then
            cp "$temp_file" "/home/arthur/.config/quickshell/heimdall/config/scheme.json"
        fi
        
        rm -f "$temp_file"
        log_success "Scheme files synchronized successfully"
        return 0
    else
        rm -f "$temp_file"
        log_error "Failed to convert scheme"
        return 1
    fi
}

# Initial sync
log_info "Starting scheme sync service..."
sync_schemes

# Watch for changes using inotifywait if available
if command -v inotifywait &> /dev/null; then
    log_info "Watching for scheme changes..."
    
    while true; do
        # Watch both possible locations
        inotifywait -q -e modify,create,moved_to \
            "$(dirname "$HEIMDALL_CLI_SCHEME")" \
            "$(dirname "$HEIMDALL_CLI_ALT")" 2>/dev/null | while read -r directory event filename; do
            
            if [[ "$filename" == "current_scheme.json" ]]; then
                log_info "Detected scheme change: $event"
                sleep 0.5  # Small delay to ensure file is fully written
                sync_schemes
            fi
        done
        
        # If inotifywait exits, wait and restart
        sleep 5
    done
else
    # Fallback: poll for changes
    log_warning "inotifywait not found, using polling mode"
    
    last_mod_time=""
    while true; do
        current_mod_time=""
        
        if [ -f "$HEIMDALL_CLI_SCHEME" ]; then
            current_mod_time=$(stat -c %Y "$HEIMDALL_CLI_SCHEME" 2>/dev/null)
        elif [ -f "$HEIMDALL_CLI_ALT" ]; then
            current_mod_time=$(stat -c %Y "$HEIMDALL_CLI_ALT" 2>/dev/null)
        fi
        
        if [ -n "$current_mod_time" ] && [ "$current_mod_time" != "$last_mod_time" ]; then
            if [ -n "$last_mod_time" ]; then  # Skip first iteration
                log_info "Detected scheme change"
                sync_schemes
            fi
            last_mod_time="$current_mod_time"
        fi
        
        sleep 5
    done
fi