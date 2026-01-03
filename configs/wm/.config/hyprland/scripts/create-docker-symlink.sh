#!/bin/bash

# Script to create a symlink for Docker Desktop's socket to /var/run/docker.sock
# This script requires sudo privileges.

INVOKING_USER=${SUDO_USER:-$(whoami)}
DOCKER_DESKTOP_SOCK="/home/$INVOKING_USER/.docker/desktop/docker.sock"
TARGET_SOCK="/var/run/docker.sock"
LOG_FILE="/tmp/create-docker-symlink.log"

# Redirect all output to log file
exec >"$LOG_FILE" 2>&1

echo "--- Docker Socket Symlink Creation Log ---"
echo "Script started at: $(date)"
echo "Running as user: $(whoami), effective user: $INVOKING_USER"

# Check if Docker Desktop's socket exists
if [ ! -S "$DOCKER_DESKTOP_SOCK" ]; then
  echo "ERROR: Docker Desktop socket not found at $DOCKER_DESKTOP_SOCK. Is Docker Desktop running?"
  exit 1
fi

# Remove existing symlink or file at target, but keep actual daemon socket if it exists
if [ -e "$TARGET_SOCK" ]; then
  if [ -L "$TARGET_SOCK" ]; then # It's a symlink
    echo "Existing symlink at $TARGET_SOCK found. Removing..."
    rm "$TARGET_SOCK"
  elif [ -S "$TARGET_SOCK" ]; then # It's a socket (likely system daemon)
    echo "ERROR: System Docker daemon socket already exists at $TARGET_SOCK. Cannot create symlink."
    echo "If you have the system Docker daemon installed, you must disable/remove it first."
    exit 1
  else # It's a regular file or directory (unexpected)
    echo "WARNING: Unexpected file or directory at $TARGET_SOCK. Attempting to remove."
    rm -rf "$TARGET_SOCK"
  fi
fi

# Create the symlink
echo "Creating symlink from $DOCKER_DESKTOP_SOCK to $TARGET_SOCK"
ln -s "$DOCKER_DESKTOP_SOCK" "$TARGET_SOCK"

# Adjust permissions if necessary (though symlink permissions are less critical, the target still matters)
# For /var/run/docker.sock, many tools expect it to be group-writable by 'docker' group.
# However, Docker Desktop's socket is user-owned. Rely on that.
# You MUST be in the 'docker' group for many tools to work with /var/run/docker.sock traditionally.
# Ensure your user is in the 'docker' group: sudo usermod -aG docker $(whoami)

echo "Symlink created. Checking result:"
ls -la "$TARGET_SOCK"
echo "Script finished at: $(date)"
echo "------------------------------------"

exit 0
