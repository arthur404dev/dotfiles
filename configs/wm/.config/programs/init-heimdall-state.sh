#!/bin/bash
# Initialize Heimdall/Quickshell state files and directories
# This script ensures all required state files exist before heimdall starts

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Define all required directories
QUICKSHELL_STATE_DIR="$HOME/.local/state/quickshell"
QUICKSHELL_USER_DIR="$QUICKSHELL_STATE_DIR/user"
QUICKSHELL_GENERATED_DIR="$QUICKSHELL_USER_DIR/generated"
QUICKSHELL_WALLPAPER_DIR="$QUICKSHELL_GENERATED_DIR/wallpaper"

HEIMDALL_SHARE_DIR="$HOME/.local/share/heimdall"
HEIMDALL_STATE_DIR="$HOME/.local/state/heimdall"

# Default values
DEFAULT_WALLPAPER="$HOME/dots/media/Pictures/Wallpapers/Autumn-Alley.jpg"

# Function to create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    local description="$2"
    
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        if [ $? -eq 0 ]; then
            log_success "Created $description: $dir"
        else
            log_error "Failed to create $description: $dir"
            return 1
        fi
    else
        log_info "$description already exists: $dir"
    fi
    return 0
}

# Function to create file with content if it doesn't exist
ensure_file() {
    local file="$1"
    local content="$2"
    local description="$3"
    
    if [ ! -f "$file" ]; then
        echo "$content" > "$file"
        if [ $? -eq 0 ]; then
            log_success "Created $description: $file"
        else
            log_error "Failed to create $description: $file"
            return 1
        fi
    else
        log_info "$description already exists: $file"
    fi
    return 0
}

# Function to find an existing wallpaper
find_wallpaper() {
    # Check various possible locations for existing wallpaper
    local wallpaper_candidates=(
        "$HOME/.local/share/heimdall/wallpaper_path"
        "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt"
        "$HOME/.config/hypr/wallpaper_path"
    )
    
    for candidate in "${wallpaper_candidates[@]}"; do
        if [ -f "$candidate" ]; then
            local wallpaper_path=$(cat "$candidate" 2>/dev/null)
            if [ -f "$wallpaper_path" ]; then
                echo "$wallpaper_path"
                return 0
            fi
        fi
    done
    
    # Return default if no valid wallpaper found
    if [ -f "$DEFAULT_WALLPAPER" ]; then
        echo "$DEFAULT_WALLPAPER"
    else
        # Find first wallpaper in wallpapers directory
        local first_wallpaper=$(find "$HOME/dots/media/Pictures/Wallpapers" -type f \( -name "*.jpg" -o -name "*.png" \) 2>/dev/null | head -1)
        if [ -n "$first_wallpaper" ]; then
            echo "$first_wallpaper"
        else
            echo ""
        fi
    fi
}

# Function to convert heimdall-cli format to Quickshell format
convert_heimdall_cli_scheme() {
    local input_file="$1"
    
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
    print(json.dumps(output, indent=2))
    
except Exception as e:
    sys.exit(1)
" 2>/dev/null
}

# Function to find or generate color scheme
find_or_generate_scheme() {
    # First check for heimdall-cli current_scheme.json and convert it
    local heimdall_cli_schemes=(
        "$HOME/.local/state/current_scheme.json"
        "$HOME/.config/heimdall-cli/current_scheme.json"
    )
    
    for candidate in "${heimdall_cli_schemes[@]}"; do
        if [ -f "$candidate" ]; then
            log_info "Found heimdall-cli scheme, converting..."
            local converted=$(convert_heimdall_cli_scheme "$candidate")
            if [ -n "$converted" ]; then
                echo "$converted"
                return 0
            fi
        fi
    done
    
    # Check for existing Quickshell format schemes
    local scheme_candidates=(
        "$HOME/.local/share/heimdall/scheme.json"
        "$HOME/.local/share/heimdall/colors.json"
        "$HOME/.local/state/quickshell/user/generated/scheme.json"
        "$HOME/.local/state/quickshell/user/generated/colors.json"
        "$HOME/.config/quickshell/heimdall/config/colors.json"
    )
    
    for candidate in "${scheme_candidates[@]}"; do
        if [ -f "$candidate" ]; then
            cat "$candidate"
            return 0
        fi
    done
    
    # Check if matugen is available to generate from wallpaper
    if command -v matugen &> /dev/null; then
        local wallpaper=$(find_wallpaper)
        if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
            log_info "Generating color scheme from wallpaper using matugen..."
            local temp_output="/tmp/matugen_scheme_$$.json"
            
            # Run matugen to generate colors
            if matugen image "$wallpaper" --json hex > "$temp_output" 2>/dev/null; then
                if [ -s "$temp_output" ]; then
                    cat "$temp_output"
                    rm -f "$temp_output"
                    return 0
                fi
            fi
            rm -f "$temp_output"
        fi
    fi
    
    # Return default scheme in Quickshell format
    cat <<'EOF'
{
  "name": "default",
  "flavour": "mocha",
  "mode": "dark",
  "variant": "dark",
  "colours": {
    "primary_paletteKeyColor": "7870AB",
    "secondary_paletteKeyColor": "78748A",
    "tertiary_paletteKeyColor": "976A7D",
    "neutral_paletteKeyColor": "79767D",
    "neutral_variant_paletteKeyColor": "797680",
    "background": "1E1E2E",
    "onBackground": "CDD6F4",
    "surface": "1E1E2E",
    "surfaceDim": "141318",
    "surfaceBright": "3A383E",
    "surfaceContainerLowest": "45475A",
    "surfaceContainerLow": "1C1B20",
    "surfaceContainer": "201F25",
    "surfaceContainerHigh": "2B292F",
    "surfaceContainerHighest": "35343A",
    "onSurface": "CDD6F4",
    "surfaceVariant": "585B70",
    "onSurfaceVariant": "C9C5D0",
    "inverseSurface": "E5E1E9",
    "inverseOnSurface": "312F36",
    "outline": "938F99",
    "outlineVariant": "48454E",
    "shadow": "000000",
    "scrim": "000000",
    "surfaceTint": "89B4FA",
    "primary": "89B4FA",
    "onPrimary": "30285F",
    "primaryContainer": "89B4FA",
    "onPrimaryContainer": "E5DEFF",
    "inversePrimary": "F5C2E7",
    "secondary": "F9E2AF",
    "onSecondary": "312E41",
    "secondaryContainer": "F9E2AF",
    "onSecondaryContainer": "E5DFF9",
    "tertiary": "A6E3A1",
    "onTertiary": "482536",
    "tertiaryContainer": "A6E3A1",
    "onTertiaryContainer": "000000",
    "error": "F38BA8",
    "onError": "690005",
    "errorContainer": "F38BA8",
    "onErrorContainer": "FFDAD6",
    "primaryFixed": "E5DEFF",
    "primaryFixedDim": "C8BFFF",
    "onPrimaryFixed": "1B1149",
    "onPrimaryFixedVariant": "473F77",
    "secondaryFixed": "E5DFF9",
    "secondaryFixedDim": "C9C3DC",
    "onSecondaryFixed": "1C192B",
    "onSecondaryFixedVariant": "484459",
    "tertiaryFixed": "FFD8E7",
    "tertiaryFixedDim": "ECB8CD",
    "onTertiaryFixed": "301121",
    "onTertiaryFixedVariant": "613B4C"
  }
}
EOF
}

# Main initialization
log_info "Starting Heimdall/Quickshell state initialization..."

# Step 1: Create all required directories
log_info "Creating required directories..."
ensure_directory "$QUICKSHELL_STATE_DIR" "Quickshell state root"
ensure_directory "$QUICKSHELL_USER_DIR" "Quickshell user directory"
ensure_directory "$QUICKSHELL_GENERATED_DIR" "Quickshell generated directory"
ensure_directory "$QUICKSHELL_WALLPAPER_DIR" "Quickshell wallpaper directory"
ensure_directory "$HEIMDALL_SHARE_DIR" "Heimdall share directory"

# Step 2: Create symlink for heimdall state if needed
if [ ! -e "$HEIMDALL_STATE_DIR" ]; then
    ln -sf "$QUICKSHELL_GENERATED_DIR" "$HEIMDALL_STATE_DIR"
    log_success "Created heimdall state symlink"
elif [ -L "$HEIMDALL_STATE_DIR" ]; then
    log_info "Heimdall state symlink already exists"
else
    log_warning "Heimdall state directory exists but is not a symlink"
fi

# Step 3: Initialize wallpaper path files
log_info "Initializing wallpaper path files..."
WALLPAPER=$(find_wallpaper)

if [ -n "$WALLPAPER" ]; then
    ensure_file "$QUICKSHELL_WALLPAPER_DIR/path.txt" "$WALLPAPER" "Quickshell wallpaper path"
    ensure_file "$HEIMDALL_SHARE_DIR/wallpaper_path" "$WALLPAPER" "Heimdall wallpaper path"
    
    # Also create a current_wallpaper file for compatibility
    ensure_file "$QUICKSHELL_GENERATED_DIR/current_wallpaper" "$WALLPAPER" "Current wallpaper file"
else
    log_error "No wallpaper found to initialize"
fi

# Step 4: Initialize color scheme files
log_info "Initializing color scheme files..."
SCHEME=$(find_or_generate_scheme)

# Save scheme to multiple locations for compatibility
ensure_file "$QUICKSHELL_GENERATED_DIR/scheme.json" "$SCHEME" "Quickshell scheme"
ensure_file "$QUICKSHELL_GENERATED_DIR/colors.json" "$SCHEME" "Quickshell colors"
ensure_file "$HEIMDALL_SHARE_DIR/scheme.json" "$SCHEME" "Heimdall scheme"
ensure_file "$HEIMDALL_SHARE_DIR/colors.json" "$SCHEME" "Heimdall colors"

# Extract primary color from scheme for color.txt
PRIMARY_COLOR=$(echo "$SCHEME" | grep -oP '"blue":\s*"\K[^"]+' | head -1 || echo "#89b4fa")
ensure_file "$QUICKSHELL_GENERATED_DIR/color.txt" "$PRIMARY_COLOR" "Primary color file"

# Step 5: Create additional compatibility files
log_info "Creating additional compatibility files..."

# Create a theme.json file
THEME_JSON='{
  "name": "generated",
  "variant": "dark",
  "wallpaper": "'$WALLPAPER'"
}'
ensure_file "$QUICKSHELL_GENERATED_DIR/theme.json" "$THEME_JSON" "Theme configuration"

# Create config symlinks if needed
if [ -d "$HOME/.config/quickshell/heimdall" ]; then
    # Link generated files to config if they don't exist
    if [ ! -f "$HOME/.config/quickshell/heimdall/config/scheme.json" ]; then
        ln -sf "$QUICKSHELL_GENERATED_DIR/scheme.json" "$HOME/.config/quickshell/heimdall/config/scheme.json"
        log_success "Created scheme symlink in heimdall config"
    fi
fi

# Step 6: Set proper permissions
log_info "Setting proper permissions..."
chmod 755 "$QUICKSHELL_STATE_DIR" 2>/dev/null
chmod 755 "$QUICKSHELL_USER_DIR" 2>/dev/null
chmod 755 "$QUICKSHELL_GENERATED_DIR" 2>/dev/null
chmod 755 "$QUICKSHELL_WALLPAPER_DIR" 2>/dev/null
chmod 755 "$HEIMDALL_SHARE_DIR" 2>/dev/null
chmod 644 "$QUICKSHELL_GENERATED_DIR"/*.json 2>/dev/null
chmod 644 "$QUICKSHELL_GENERATED_DIR"/*.txt 2>/dev/null
chmod 644 "$QUICKSHELL_WALLPAPER_DIR"/*.txt 2>/dev/null
chmod 644 "$HEIMDALL_SHARE_DIR"/*.json 2>/dev/null

# Step 7: Verify all critical files exist
log_info "Verifying critical files..."
CRITICAL_FILES=(
    "$QUICKSHELL_GENERATED_DIR/scheme.json"
    "$QUICKSHELL_GENERATED_DIR/colors.json"
    "$QUICKSHELL_WALLPAPER_DIR/path.txt"
    "$HEIMDALL_SHARE_DIR/scheme.json"
    "$HEIMDALL_SHARE_DIR/wallpaper_path"
)

ALL_GOOD=true
for file in "${CRITICAL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "Critical file missing: $file"
        ALL_GOOD=false
    else
        log_success "Verified: $file"
    fi
done

if [ "$ALL_GOOD" = true ]; then
    log_success "All critical state files initialized successfully!"
    exit 0
else
    log_error "Some critical files are still missing"
    exit 1
fi