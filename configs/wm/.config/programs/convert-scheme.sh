#!/bin/bash
# Manual scheme conversion script for testing
# Converts heimdall-cli current_scheme.json to Quickshell format

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to convert and display scheme
convert_scheme() {
    local input_file="$1"
    
    if [ ! -f "$input_file" ]; then
        log_error "File not found: $input_file"
        return 1
    fi
    
    log_info "Converting scheme from: $input_file"
    
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
    color_mappings = {
        'background': 'background',
        'foreground': 'onBackground',
        'color0': 'surfaceContainerLowest',
        'color1': 'error',
        'color2': 'tertiary',
        'color3': 'secondary',
        'color4': 'primary',
        'color5': 'primary_paletteKeyColor',
        'color6': 'tertiary_paletteKeyColor',
        'color7': 'surface',
        'color8': 'surfaceVariant',
        'color9': 'errorContainer',
        'color10': 'tertiaryContainer',
        'color11': 'secondaryContainer',
        'color12': 'primaryContainer',
        'color13': 'inversePrimary',
        'color14': 'inverseSurface',
        'color15': 'onSurface',
    }
    
    # Process colors
    for key, value in color_map.items():
        hex_value = None
        if isinstance(value, dict) and 'hex' in value:
            hex_value = value['hex'].lstrip('#')
        elif isinstance(value, str):
            hex_value = value.lstrip('#')
        
        if hex_value and key in color_mappings:
            colours[color_mappings[key]] = hex_value
    
    # Fill in missing M3 colors with defaults
    default_colors = {
        'primary_paletteKeyColor': '7870AB',
        'secondary_paletteKeyColor': '78748A',
        'tertiary_paletteKeyColor': '976A7D',
        'neutral_paletteKeyColor': '79767D',
        'neutral_variant_paletteKeyColor': '797680',
        'surfaceDim': '141318',
        'surfaceBright': '3A383E',
        'surfaceContainerLow': '1C1B20',
        'surfaceContainer': '201F25',
        'surfaceContainerHigh': '2B292F',
        'surfaceContainerHighest': '35343A',
        'onSurfaceVariant': 'C9C5D0',
        'inverseOnSurface': '312F36',
        'outline': '938F99',
        'outlineVariant': '48454E',
        'shadow': '000000',
        'scrim': '000000',
        'surfaceTint': 'C8BFFF',
        'onPrimary': '30285F',
        'onPrimaryContainer': 'E5DEFF',
        'onSecondary': '312E41',
        'onSecondaryContainer': 'E5DFF9',
        'onTertiary': '482536',
        'onTertiaryContainer': '000000',
        'onError': '690005',
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
    
    for key, value in default_colors.items():
        if key not in colours:
            colours[key] = value
    
    output['colours'] = colours
    
    # Pretty print the output
    print(json.dumps(output, indent=2))
    
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# Function to apply converted scheme
apply_scheme() {
    local input_file="$1"
    local temp_file="/tmp/converted_scheme_$$.json"
    
    log_info "Converting and applying scheme..."
    
    if convert_scheme "$input_file" > "$temp_file"; then
        # Copy to all required locations
        QUICKSHELL_STATE_DIR="$HOME/.local/state/quickshell/user/generated"
        HEIMDALL_SHARE_DIR="$HOME/.local/share/heimdall"
        
        mkdir -p "$QUICKSHELL_STATE_DIR"
        mkdir -p "$HEIMDALL_SHARE_DIR"
        
        cp "$temp_file" "$QUICKSHELL_STATE_DIR/scheme.json"
        cp "$temp_file" "$QUICKSHELL_STATE_DIR/colors.json"
        cp "$temp_file" "$HEIMDALL_SHARE_DIR/scheme.json"
        cp "$temp_file" "$HEIMDALL_SHARE_DIR/colors.json"
        
        if [ -d "$HOME/.config/quickshell/heimdall/config" ]; then
            cp "$temp_file" "$HOME/.config/quickshell/heimdall/config/scheme.json"
        fi
        
        rm -f "$temp_file"
        log_success "Scheme applied to all locations successfully!"
        
        log_info "Updated files:"
        echo "  - $QUICKSHELL_STATE_DIR/scheme.json"
        echo "  - $QUICKSHELL_STATE_DIR/colors.json"
        echo "  - $HEIMDALL_SHARE_DIR/scheme.json"
        echo "  - $HEIMDALL_SHARE_DIR/colors.json"
        
        return 0
    else
        rm -f "$temp_file"
        log_error "Failed to convert scheme"
        return 1
    fi
}

# Main script
if [ $# -eq 0 ]; then
    # No arguments - try to find and convert current_scheme.json
    log_info "Looking for heimdall-cli current_scheme.json..."
    
    FOUND=false
    for file in "$HOME/.local/state/current_scheme.json" "$HOME/.config/heimdall-cli/current_scheme.json"; do
        if [ -f "$file" ]; then
            log_success "Found: $file"
            echo ""
            convert_scheme "$file"
            FOUND=true
            
            echo ""
            read -p "Apply this scheme to Quickshell? (y/n) " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                apply_scheme "$file"
            fi
            break
        fi
    done
    
    if [ "$FOUND" = false ]; then
        log_error "No current_scheme.json found in expected locations"
        echo ""
        echo "Usage: $0 [options] [file]"
        echo ""
        echo "Options:"
        echo "  -h, --help     Show this help message"
        echo "  -a, --apply    Apply the converted scheme to Quickshell"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Find and convert current_scheme.json"
        echo "  $0 /path/to/scheme.json              # Convert specific file"
        echo "  $0 -a /path/to/scheme.json           # Convert and apply scheme"
        exit 1
    fi
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Heimdall-CLI to Quickshell Scheme Converter"
    echo ""
    echo "Usage: $0 [options] [file]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -a, --apply    Apply the converted scheme to Quickshell"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Find and convert current_scheme.json"
    echo "  $0 /path/to/scheme.json              # Convert specific file"
    echo "  $0 -a /path/to/scheme.json           # Convert and apply scheme"
elif [ "$1" = "-a" ] || [ "$1" = "--apply" ]; then
    if [ -z "$2" ]; then
        # Try to find current_scheme.json
        FOUND=false
        for file in "$HOME/.local/state/current_scheme.json" "$HOME/.config/heimdall-cli/current_scheme.json"; do
            if [ -f "$file" ]; then
                apply_scheme "$file"
                FOUND=true
                break
            fi
        done
        
        if [ "$FOUND" = false ]; then
            log_error "No current_scheme.json found and no file specified"
            exit 1
        fi
    else
        apply_scheme "$2"
    fi
else
    # Convert the specified file
    convert_scheme "$1"
fi