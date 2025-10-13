#!/usr/bin/env bash
set -e

# Wyoming Kokoro TTS - System Uninstallation Script

INSTALL_DIR="/opt/wyoming-kokoro"
SERVICE_NAME="wyoming-kokoro"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Wyoming Kokoro TTS System Uninstallation ===${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Confirm uninstallation
read -p "Are you sure you want to uninstall Wyoming Kokoro? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo -e "${GREEN}Step 1: Stopping service${NC}"
if systemctl is-active --quiet $SERVICE_NAME; then
    systemctl stop $SERVICE_NAME
    echo "Service stopped"
else
    echo "Service not running"
fi

echo -e "${GREEN}Step 2: Disabling service${NC}"
if systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
    systemctl disable $SERVICE_NAME
    echo "Service disabled"
else
    echo "Service not enabled"
fi

echo -e "${GREEN}Step 3: Removing service file${NC}"
if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
    rm /etc/systemd/system/$SERVICE_NAME.service
    echo "Service file removed"
fi

echo -e "${GREEN}Step 4: Reloading systemd${NC}"
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

echo -e "${GREEN}Step 5: Removing installation directory${NC}"
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
    echo "Installation directory removed: $INSTALL_DIR"
else
    echo "Installation directory not found"
fi

echo
echo -e "${GREEN}=== Uninstallation Complete ===${NC}"
echo
echo "Wyoming Kokoro has been removed from your system."
echo
