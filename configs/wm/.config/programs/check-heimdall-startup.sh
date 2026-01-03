#!/bin/bash
# Heimdall/Quickshell Startup Diagnostic Script
# Checks all components and state files for proper operation

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Diagnostic results file
DIAG_FILE="/tmp/heimdall-diagnostic-$(date +%Y%m%d-%H%M%S).log"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Heimdall/Quickshell Startup Diagnostics${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
    echo "=== $1 ===" >> "$DIAG_FILE"
}

# Function to check status
check_status() {
    local description="$1"
    local condition="$2"
    
    if eval "$condition"; then
        echo -e "${GREEN}✓${NC} $description"
        echo "✓ $description" >> "$DIAG_FILE"
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo "✗ $description" >> "$DIAG_FILE"
        return 1
    fi
}

# Function to print info
print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
    echo "ℹ $1" >> "$DIAG_FILE"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    echo "⚠ $1" >> "$DIAG_FILE"
}

# Function to print error
print_error() {
    echo -e "${RED}✗${NC} $1"
    echo "✗ $1" >> "$DIAG_FILE"
}

# Initialize diagnostic log
echo "Heimdall/Quickshell Diagnostic Report - $(date)" > "$DIAG_FILE"
echo "================================================" >> "$DIAG_FILE"

# 1. Check Environment
print_section "Environment Check"

check_status "Wayland display available" "[ -n \"\$WAYLAND_DISPLAY\" ]"
if [ -n "$WAYLAND_DISPLAY" ]; then
    print_info "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
fi

check_status "XDG_RUNTIME_DIR set" "[ -n \"\$XDG_RUNTIME_DIR\" ]"
if [ -n "$XDG_RUNTIME_DIR" ]; then
    print_info "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
fi

check_status "HOME directory set" "[ -n \"\$HOME\" ]"

# 2. Check Required Commands
print_section "Required Commands"

COMMANDS=("heimdall" "quickshell" "swww-daemon" "hyprpaper" "hyprctl")
for cmd in "${COMMANDS[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        VERSION=$($cmd --version 2>&1 | head -1 || echo "version unknown")
        check_status "$cmd installed" "true"
        print_info "$cmd: $VERSION"
    else
        check_status "$cmd installed" "false"
    fi
done

# 3. Check Running Processes
print_section "Process Status"

PROCESSES=(
    "swww-daemon:Wallpaper daemon (swww)"
    "hyprpaper:Wallpaper daemon (hyprpaper)"
    "heimdall shell:Heimdall shell daemon"
    "heimdall pip:Heimdall PIP daemon"
    "quickshell:Quickshell main process"
)

for proc_desc in "${PROCESSES[@]}"; do
    IFS=':' read -r proc desc <<< "$proc_desc"
    if pgrep -f "$proc" > /dev/null; then
        PID=$(pgrep -f "$proc" | head -1)
        check_status "$desc running" "true"
        print_info "PID: $PID"
    else
        check_status "$desc running" "false"
    fi
done

# 4. Check State Directories
print_section "State Directories"

DIRS=(
    "$HOME/.local/state/quickshell/user/generated:Quickshell state directory"
    "$HOME/.local/state/quickshell/user/generated/wallpaper:Quickshell wallpaper directory"
    "$HOME/.local/share/heimdall:Heimdall share directory"
    "$HOME/.local/state/heimdall:Heimdall state directory (legacy)"
)

for dir_desc in "${DIRS[@]}"; do
    IFS=':' read -r dir desc <<< "$dir_desc"
    if [ -d "$dir" ]; then
        check_status "$desc exists" "true"
        
        # Check if it's a symlink
        if [ -L "$dir" ]; then
            TARGET=$(readlink -f "$dir")
            print_info "  Symlink to: $TARGET"
        fi
        
        # Check permissions
        if [ -w "$dir" ]; then
            print_info "  Writable: Yes"
        else
            print_warning "  Writable: No"
        fi
    else
        check_status "$desc exists" "false"
    fi
done

# 5. Check State Files
print_section "State Files"

FILES=(
    "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt:Wallpaper path (Quickshell)"
    "$HOME/.local/share/heimdall/wallpaper_path:Wallpaper path (Heimdall)"
    "$HOME/.local/state/quickshell/user/generated/colors.json:Color scheme (Quickshell)"
    "$HOME/.local/state/quickshell/user/generated/color.txt:Color text file"
    "$HOME/.local/share/heimdall/scheme.json:Color scheme (Heimdall)"
)

for file_desc in "${FILES[@]}"; do
    IFS=':' read -r file desc <<< "$file_desc"
    if [ -f "$file" ]; then
        check_status "$desc exists" "true"
        
        # Check if it's a symlink
        if [ -L "$file" ]; then
            TARGET=$(readlink -f "$file")
            print_info "  Symlink to: $TARGET"
        fi
        
        # Check file size
        SIZE=$(stat -c%s "$file" 2>/dev/null || echo "0")
        if [ "$SIZE" -gt 0 ]; then
            print_info "  Size: $SIZE bytes"
            
            # For wallpaper files, check if the wallpaper exists
            if [[ "$file" == *"wallpaper"* ]] && [[ "$file" == *"path"* ]]; then
                WALLPAPER_PATH=$(cat "$file" 2>/dev/null)
                if [ -n "$WALLPAPER_PATH" ]; then
                    if [ -f "$WALLPAPER_PATH" ]; then
                        print_info "  Points to: $WALLPAPER_PATH (exists)"
                    else
                        print_error "  Points to: $WALLPAPER_PATH (NOT FOUND)"
                    fi
                fi
            fi
        else
            print_warning "  File is empty"
        fi
    else
        check_status "$desc exists" "false"
    fi
done

# 6. Check Wallpaper Status
print_section "Wallpaper Status"

# Check current wallpaper with swww
if command -v swww &> /dev/null && pgrep -x "swww-daemon" > /dev/null; then
    CURRENT_WALLPAPER=$(swww query 2>/dev/null | grep -oP 'image: \K.*' | head -1)
    if [ -n "$CURRENT_WALLPAPER" ]; then
        check_status "Wallpaper set in swww" "true"
        print_info "Current wallpaper: $CURRENT_WALLPAPER"
        
        if [ -f "$CURRENT_WALLPAPER" ]; then
            print_info "Wallpaper file exists"
        else
            print_error "Wallpaper file not found!"
        fi
    else
        check_status "Wallpaper set in swww" "false"
    fi
fi

# Check hyprpaper config
if command -v hyprpaper &> /dev/null && pgrep -x "hyprpaper" > /dev/null; then
    print_info "Hyprpaper is running"
    
    # Try to get wallpaper from hyprctl
    HYPR_WALLPAPER=$(hyprctl hyprpaper listactive 2>/dev/null | head -1)
    if [ -n "$HYPR_WALLPAPER" ]; then
        print_info "Hyprpaper wallpaper: $HYPR_WALLPAPER"
    fi
fi

# 7. Check Recent Logs
print_section "Recent Log Entries"

LOG_FILES=(
    "/tmp/quickshell-startup.log:Startup log"
    "/tmp/quickshell-startup-errors.log:Error log"
)

for log_desc in "${LOG_FILES[@]}"; do
    IFS=':' read -r log desc <<< "$log_desc"
    if [ -f "$log" ]; then
        print_info "$desc: $log"
        
        # Check for recent errors
        ERROR_COUNT=$(grep -c "ERROR" "$log" 2>/dev/null || echo "0")
        if [ "$ERROR_COUNT" -gt 0 ]; then
            print_warning "  Contains $ERROR_COUNT error(s)"
            print_info "  Last 3 errors:"
            grep "ERROR" "$log" | tail -3 | while read line; do
                echo "    $line"
                echo "    $line" >> "$DIAG_FILE"
            done
        fi
        
        # Show last modification time
        LAST_MOD=$(stat -c %y "$log" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        print_info "  Last modified: $LAST_MOD"
    else
        print_info "$desc: Not found"
    fi
done

# 8. Check Heimdall Communication
print_section "Heimdall Communication Test"

if command -v heimdall &> /dev/null; then
    # Try to get shell status
    print_info "Testing heimdall shell status..."
    if heimdall shell status &> /dev/null; then
        check_status "Heimdall shell responding" "true"
    else
        check_status "Heimdall shell responding" "false"
        print_warning "Heimdall shell may not be running or not responding"
    fi
    
    # Try to get scheme info
    print_info "Testing heimdall scheme..."
    SCHEME_OUTPUT=$(heimdall scheme current 2>&1)
    if [ $? -eq 0 ]; then
        check_status "Heimdall scheme accessible" "true"
        print_info "Current scheme: $(echo "$SCHEME_OUTPUT" | head -1)"
    else
        check_status "Heimdall scheme accessible" "false"
    fi
fi

# 9. System Resource Check
print_section "System Resources"

# Check memory
MEM_AVAILABLE=$(free -m | awk '/^Mem:/{print $7}')
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
print_info "Memory: ${MEM_AVAILABLE}MB available of ${MEM_TOTAL}MB total"

# Check disk space for state directories
for dir in "$HOME/.local/state" "$HOME/.local/share"; do
    if [ -d "$dir" ]; then
        DISK_AVAIL=$(df -h "$dir" | awk 'NR==2{print $4}')
        print_info "Disk space for $dir: $DISK_AVAIL available"
    fi
done

# 10. Recommendations
print_section "Diagnostic Summary"

ISSUES_FOUND=false

# Check for common issues
if ! pgrep -f "quickshell" > /dev/null; then
    print_error "Quickshell is not running!"
    print_info "  Try: quickshell --config ~/.config/quickshell/heimdall"
    ISSUES_FOUND=true
fi

if ! pgrep -x "swww-daemon" > /dev/null && ! pgrep -x "hyprpaper" > /dev/null; then
    print_error "No wallpaper daemon is running!"
    print_info "  Try: swww-daemon --format xrgb &"
    ISSUES_FOUND=true
fi

if [ ! -f "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt" ]; then
    print_error "Wallpaper path file is missing!"
    print_info "  Try: ~/.config/hypr/programs/wallpaper-sync.sh /path/to/wallpaper.jpg"
    ISSUES_FOUND=true
fi

if [ ! -f "$HOME/.local/state/quickshell/user/generated/colors.json" ]; then
    print_warning "Color scheme file is missing!"
    print_info "  Try: heimdall scheme generate /path/to/wallpaper.jpg"
    ISSUES_FOUND=true
fi

if [ "$ISSUES_FOUND" = false ]; then
    echo -e "\n${GREEN}✓ All checks passed! System appears to be configured correctly.${NC}"
    echo "✓ All checks passed!" >> "$DIAG_FILE"
else
    echo -e "\n${YELLOW}⚠ Some issues were found. See recommendations above.${NC}"
    echo "⚠ Issues found - see recommendations" >> "$DIAG_FILE"
fi

# Save diagnostic file location
echo -e "\n${CYAN}Diagnostic report saved to: $DIAG_FILE${NC}"

# Offer to run startup orchestrator if issues found
if [ "$ISSUES_FOUND" = true ]; then
    echo -e "\n${YELLOW}Would you like to run the startup orchestrator now? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Running startup orchestrator...${NC}"
        ~/.config/hypr/programs/startup-orchestrator.sh
    fi
fi