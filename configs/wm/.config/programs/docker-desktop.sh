#!/bin/bash
# Simple Docker Desktop startup script
# Avoids complex systemd manipulation that causes failures

# Check if Docker Desktop is installed
if ! command -v docker-desktop &> /dev/null; then
    echo "Docker Desktop is not installed"
    exit 0
fi

# Check if already running
if pgrep -f "docker-desktop" > /dev/null; then
    echo "Docker Desktop is already running"
    exit 0
fi

# Start Docker Desktop in background
echo "Starting Docker Desktop..."
docker-desktop &> /dev/null &

echo "Docker Desktop launch initiated"