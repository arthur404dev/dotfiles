#!/bin/bash

# Script to launch EasyEffects Flatpak in the background
# Ensure this script is executable: chmod +x ~/.config/hypr/hyprland/scripts/start_easyeffects.sh

# --- Configuration ---
# Optional: Get your current DBUS_SESSION_BUS_ADDRESS if you think environment
# issues are still present, otherwise comment this line out.
# This variable is crucial for GUI applications to communicate via D-Bus.
# DBUS_ADDRESS=$(loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p DBUS_SEAT_UNIT)
# You can also get it from `echo $DBUS_SESSION_BUS_ADDRESS` in a working session.
# For now, let's rely on import-environment in Hyprland config.

EASY_EFFECTS_COMMAND="/usr/bin/flatpak run com.github.wwmm.easyeffects --gapplication-service"
LOG_FILE="/tmp/easyeffects-autostart.log"
DELAY_SECONDS=5 # Delay before launching, in seconds

# --- Script Logic ---

# Redirect all output to a log file for debugging
exec >"$LOG_FILE" 2>&1

echo "--- EasyEffects Autostart Log ---"
echo "Script started at: $(date)"
echo "Delaying for $DELAY_SECONDS seconds..."
sleep "$DELAY_SECONDS"
echo "Delay finished. Attempting to launch EasyEffects..."

# Ensure we have a valid DBUS_SESSION_BUS_ADDRESS (for debugging, if needed)
# if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
#     echo "WARNING: DBUS_SESSION_BUS_ADDRESS not set in this context."
#     # Attempt to find it, or use a known one. This is a fallback, not ideal.
#     # You already handle this with `import-environment` in Hyprland config.
# fi
echo "Current DBUS_SESSION_BUS_ADDRESS: $DBUS_SESSION_BUS_ADDRESS"
echo "Current WAYLAND_DISPLAY: $WAYLAND_DISPLAY"
echo "Current XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
echo "Current DISPLAY: $DISPLAY"

# Launch EasyEffects in the background
# Use `nohup` to ensure it keeps running even if the parent shell exits
# Use `eval` to handle potential complex arguments if needed, but for flatpak it's fine direct.
nohup sh -c "$EASY_EFFECTS_COMMAND" &

echo "EasyEffects launch command issued."
echo "Script finished at: $(date)"
echo "-----------------------------------"

exit 0
