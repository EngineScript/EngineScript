#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# Create tools directory if it doesn't exist
mkdir -p /var/www/admin/tools

# Download and install official Tiny File Manager from GitHub
echo "Installing official Tiny File Manager from GitHub..."
TFM_DIR="/var/www/admin/tools/tinyfilemanager"
TFM_ZIP_URL="https://github.com/prasathmani/tinyfilemanager/archive/refs/tags/${TINYFILEMANAGER_VER}.tar.gz"
TFM_ZIP_FILE="/tmp/tinyfilemanager-${TINYFILEMANAGER_VER}.tar.gz"

# Remove existing TFM directory if it exists
if [[ -d "$TFM_DIR" ]]; then
    rm -rf "$TFM_DIR"
fi

# Create TFM directory if it doesn't exist
if [[ ! -d "$TFM_DIR" ]]; then
    mkdir -p "$TFM_DIR"
fi

# Download and extract TFM with error handling
if curl -fsSL --connect-timeout 30 --max-time 60 "${TFM_ZIP_URL}" -o "${TFM_ZIP_FILE}"; then
    if tar -xzf "${TFM_ZIP_FILE}" -C /tmp/; then
        # Copy files from extracted directory to our target directory
        cp -r "/tmp/tinyfilemanager-${TINYFILEMANAGER_VER}/"* "$TFM_DIR/"
        
        # Copy our custom configuration file
        # Config templates are stored in /config/var/www/admin/tools/ to mirror the install location
        if [[ -f "/usr/local/bin/enginescript/config/var/www/admin/tools/tinyfilemanager/config.php" ]]; then
            cp /usr/local/bin/enginescript/config/var/www/admin/tools/tinyfilemanager/config.php "$TFM_DIR/"
        fi
        
        # Set proper permissions
        find "$TFM_DIR" -type f -name "*.php" -exec chmod 644 {} \;
        find "$TFM_DIR" -type f -name "*.md" -exec chmod 644 {} \;
        find "$TFM_DIR" -type f -name "*.txt" -exec chmod 644 {} \;
        find "$TFM_DIR" -type d -exec chmod 755 {} \;
        chmod 755 "$TFM_DIR"
        
        # Clean up
        rm -f "${TFM_ZIP_FILE}"
        rm -rf "/tmp/tinyfilemanager-${TINYFILEMANAGER_VER}"
        
        echo "✓ Official Tiny File Manager v${TINYFILEMANAGER_VER} installed successfully"
        echo "  - Location: $TFM_DIR"
        echo "  - Access URL: /tinyfilemanager/tinyfilemanager.php"
        echo "  - Login: Uses credentials from main EngineScript configuration"
    else
        echo "⚠ Warning: Failed to extract Tiny File Manager archive"
    fi
else
    echo "⚠ Warning: Failed to download Tiny File Manager from GitHub"
fi

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
cd /usr/src
