#!/usr/bin/env bash

# Enhanced program launcher for Hyprland with composition support
# Usage: launch_program.sh <program_type> [additional_args...]
# Example: launch_program.sh terminal --additional-args
# Composition: launch_program.sh terminal-multiplexer

PROGRAM_TYPE="$1"
shift  # Remove program type from arguments, leaving additional args

# Configuration directory
PROGRAMS_DIR="$HOME/.config/hypr/programs"
FALLBACK_SCRIPT="$HOME/.config/hypr/hyprland/scripts/launch_first_available.sh"

# Function to log messages
log_message() {
    echo "[launch_program] $1" >&2
}

# Function to read program config
read_program_config() {
    local program_type="$1"
    local config_file="$PROGRAMS_DIR/$program_type"
    
    if [[ -f "$config_file" ]]; then
        cat "$config_file" | head -n1 | xargs
    else
        echo ""
    fi
}

# Function to check if program exists
program_exists() {
    local program_name="$1"
    
    # Handle tilde expansion for paths starting with ~
    if [[ "$program_name" == ~* ]]; then
        program_name="${program_name/#\~/$HOME}"
    fi
    
    command -v "$program_name" >/dev/null 2>&1 || [[ -x "$program_name" ]]
}

# Function to execute command with proper handling
execute_command() {
    local cmd="$1"
    local additional_args="$2"
    
    # If additional args provided, append them
    if [[ -n "$additional_args" ]]; then
        cmd="$cmd $additional_args"
    fi
    
    log_message "Executing: $cmd"
    eval "$cmd" &
}

# Function to compose programs (e.g., terminal-multiplexer)
compose_programs() {
    local composition_type="$1"
    local additional_args="$2"
    
    case "$composition_type" in
        "terminal-multiplexer")
            local terminal_cmd=$(read_program_config "terminal")
            local multiplexer_cmd=$(read_program_config "multiplexer")
            
            if [[ -n "$terminal_cmd" && -n "$multiplexer_cmd" ]]; then
                # Extract terminal program name for validation
                local terminal_name=$(echo "$terminal_cmd" | awk '{print $1}')
                local multiplexer_name=$(echo "$multiplexer_cmd" | awk '{print $1}')
                
                if program_exists "$terminal_name" && program_exists "$multiplexer_name"; then
                    # Use fish shell to preserve theme and environment
                    local composed_cmd="$terminal_cmd -e fish -c \"$multiplexer_cmd\""
                    execute_command "$composed_cmd" "$additional_args"
                    return 0
                else
                    log_message "Warning: Terminal ($terminal_name) or multiplexer ($multiplexer_name) not found"
                fi
            else
                log_message "Warning: Missing terminal or multiplexer configuration"
            fi
            
            # Fallback to hardcoded composition
            log_message "Falling back to hardcoded terminal-multiplexer"
            execute_command "kitty -1 -e fish -c \"zellij\"" "$additional_args"
            return 0
            ;;
        "terminal-file-manager-tui")
            local terminal_cmd=$(read_program_config "terminal")
            local file_manager_tui_cmd=$(read_program_config "file-manager-tui")
            
            if [[ -n "$terminal_cmd" && -n "$file_manager_tui_cmd" ]]; then
                local terminal_name=$(echo "$terminal_cmd" | awk '{print $1}')
                local file_manager_name=$(echo "$file_manager_tui_cmd" | awk '{print $1}')
                
                if program_exists "$terminal_name" && program_exists "$file_manager_name"; then
                    local composed_cmd="$terminal_cmd -e fish -c \"$file_manager_tui_cmd\""
                    execute_command "$composed_cmd" "$additional_args"
                    return 0
                fi
            fi
            
            # Fallback
            log_message "Falling back to hardcoded terminal-file-manager-tui"
            execute_command "kitty -1 -e fish -c \"yazi\"" "$additional_args"
            return 0
            ;;
        "terminal-text-editor-tui")
            local terminal_cmd=$(read_program_config "terminal")
            local text_editor_tui_cmd=$(read_program_config "text-editor-tui")
            
            if [[ -n "$terminal_cmd" && -n "$text_editor_tui_cmd" ]]; then
                local terminal_name=$(echo "$terminal_cmd" | awk '{print $1}')
                local editor_name=$(echo "$text_editor_tui_cmd" | awk '{print $1}')
                
                if program_exists "$terminal_name" && program_exists "$editor_name"; then
                    local composed_cmd="$terminal_cmd -e fish -c \"$text_editor_tui_cmd\""
                    execute_command "$composed_cmd" "$additional_args"
                    return 0
                fi
            fi
            
            # Fallback
            log_message "Falling back to hardcoded terminal-text-editor-tui"
            execute_command "kitty -1 -e fish -c \"nvim\"" "$additional_args"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Main logic
if [[ -z "$PROGRAM_TYPE" ]]; then
    log_message "Error: No program type specified"
    log_message "Usage: launch_program.sh <program_type> [additional_args...]"
    exit 1
fi

# Check if this is a composition type
if compose_programs "$PROGRAM_TYPE" "$*"; then
    exit 0
fi

# Regular program handling
PROGRAM_CONFIG="$PROGRAMS_DIR/$PROGRAM_TYPE"

# Check if program config file exists
if [[ -f "$PROGRAM_CONFIG" ]]; then
    # Read the preferred program from config file
    PREFERRED_PROGRAM=$(read_program_config "$PROGRAM_TYPE")
    
    if [[ -n "$PREFERRED_PROGRAM" ]]; then
        # Check if the program exists (extract just the program name for checking)
        PROGRAM_NAME=$(echo "$PREFERRED_PROGRAM" | awk '{print $1}')
        
        if program_exists "$PROGRAM_NAME"; then
            execute_command "$PREFERRED_PROGRAM" "$*"
            exit 0
        else
            log_message "Warning: Configured program '$PROGRAM_NAME' not found"
        fi
    else
        log_message "Warning: Empty configuration file: $PROGRAM_CONFIG"
    fi
else
    log_message "Warning: No configuration file found: $PROGRAM_CONFIG"
fi

# Fallback behavior based on program type
case "$PROGRAM_TYPE" in
    "terminal")
        log_message "Falling back to terminal alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "kitty -1" "foot" "alacritty" "wezterm" "konsole" "kgx" "uxterm" "xterm"
        fi
        ;;
    "terminal-multiplexer")
        log_message "Falling back to terminal with multiplexer alternatives"
        execute_command "kitty -1 -e fish -c \"zellij\"" "$*"
        exit 0
        ;;
    "multiplexer")
        log_message "Falling back to multiplexer alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "zellij" "tmux" "screen"
        fi
        ;;
    "file-manager")
        log_message "Falling back to file manager alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "nemo" "dolphin" "nautilus" "thunar"
        fi
        ;;
    "browser")
        log_message "Falling back to browser alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "google-chrome-stable" "zen-browser" "firefox" "brave" "chromium" "microsoft-edge-stable" "opera" "librewolf"
        fi
        ;;
    "code-editor")
        log_message "Falling back to code editor alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "code" "codium" "cursor" "zed" "zedit" "zeditor" "kate" "gnome-text-editor" "emacs"
        fi
        ;;
    "terminal-file-manager-tui")
        log_message "Falling back to terminal file manager alternatives"
        execute_command "kitty -1 -e fish -c \"yazi\"" "$*"
        exit 0
        ;;
    "terminal-text-editor-tui")
        log_message "Falling back to terminal text editor alternatives"
        execute_command "kitty -1 -e fish -c \"nvim\"" "$*"
        exit 0
        ;;
    "text-editor")
        log_message "Falling back to text editor alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "kate" "gnome-text-editor" "emacs"
        fi
        ;;
    "office-suite")
        log_message "Falling back to office suite alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "wps" "onlyoffice-desktopeditors"
        fi
        ;;
    "volume-mixer")
        log_message "Falling back to volume mixer alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "pavucontrol-qt" "pavucontrol"
        fi
        ;;
    "settings-app")
        log_message "Falling back to settings app alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "systemsettings" "gnome-control-center" "better-control"
        fi
        ;;
    "task-manager")
        log_message "Falling back to task manager alternatives"
        if [[ -x "$FALLBACK_SCRIPT" ]]; then
            exec "$FALLBACK_SCRIPT" "gnome-system-monitor" "plasma-systemmonitor --page-name Processes" "command -v btop && kitty -1 fish -c btop"
        fi
        ;;
    "launcher")
        log_message "Falling back to launcher alternatives"
        execute_command "fuzzel" "$*"
        exit 0
        ;;
    "clipboard-manager")
        log_message "Falling back to clipboard manager alternatives"
        execute_command "cliphist list | fuzzel --match-mode fzf --dmenu | cliphist decode | wl-copy" "$*"
        exit 0
        ;;
    "screenshot-tool")
        log_message "Falling back to screenshot tool alternatives"
        execute_command "hyprshot --freeze --mode region" "$*"
        exit 0
        ;;
    "emoji-picker")
        log_message "Falling back to emoji picker alternatives"
        execute_command "~/.config/hypr/hyprland/scripts/fuzzel-emoji.sh copy" "$*"
        exit 0
        ;;
    *)
        log_message "Error: Unknown program type '$PROGRAM_TYPE'"
        log_message "Available types: terminal, terminal-multiplexer, multiplexer, file-manager, terminal-file-manager-tui, browser, code-editor, text-editor, terminal-text-editor-tui, file-manager-tui, text-editor-tui, office-suite, volume-mixer, settings-app, task-manager, launcher, clipboard-manager, screenshot-tool, emoji-picker"
        exit 1
        ;;
esac

log_message "Error: All fallback options failed for program type '$PROGRAM_TYPE'"
exit 1