#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript File Manager Password Reset Tool
#----------------------------------------------------------------------------------
# This script allows administrators to reset the file manager password
# Updates both the main credentials file and the file manager config
#----------------------------------------------------------------------------------

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)" 
   exit 1
fi

CREDENTIALS_FILE="/home/EngineScript/enginescript-install-options.txt"
CONFIG_FILE="/etc/enginescript/filemanager.conf"

# Check if credentials file exists
if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    echo "Error: Main credentials file not found at $CREDENTIALS_FILE"
    echo "Please ensure EngineScript is properly installed."
    exit 1
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: File manager configuration not found at $CONFIG_FILE"
    echo "Please run the admin control panel installation first."
    exit 1
fi

echo "EngineScript File Manager Password Reset"
echo "========================================"
echo ""

# Get current username from credentials file
CURRENT_USERNAME=$(grep "^FILEMANAGER_USERNAME=" "$CREDENTIALS_FILE" | cut -d'"' -f2)
if [[ "$CURRENT_USERNAME" == "PLACEHOLDER" ]] || [[ -z "$CURRENT_USERNAME" ]]; then
    CURRENT_USERNAME="admin"
fi

# Prompt for new username
read -p "Enter username (current: $CURRENT_USERNAME, press enter to keep): " NEW_USERNAME
if [[ -z "$NEW_USERNAME" ]]; then
    NEW_USERNAME="$CURRENT_USERNAME"
fi

# Prompt for new password or generate one
read -p "Enter new password (leave blank to generate): " NEW_PASSWORD

if [[ -z "$NEW_PASSWORD" ]]; then
    NEW_PASSWORD=$(openssl rand -base64 16 | tr -d '/+=' | head -c 12)
    echo "Generated password: $NEW_PASSWORD"
fi

# Update main credentials file
sed -i "s|FILEMANAGER_USERNAME=\".*\"|FILEMANAGER_USERNAME=\"${NEW_USERNAME}\"|g" "$CREDENTIALS_FILE"
sed -i "s|FILEMANAGER_PASSWORD=\".*\"|FILEMANAGER_PASSWORD=\"${NEW_PASSWORD}\"|g" "$CREDENTIALS_FILE"

# Update configuration file using the shared updater
echo "Updating configuration files..."
/usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh

echo ""
echo "============================================="
echo "File Manager Credentials Updated Successfully!"
echo "Username: $NEW_USERNAME"
echo "Password: $NEW_PASSWORD"
echo "============================================="
echo "IMPORTANT: Save these credentials securely!"
echo ""

# Log the password reset
logger "EngineScript: File manager credentials reset by $(whoami)"

echo "Password reset completed."
