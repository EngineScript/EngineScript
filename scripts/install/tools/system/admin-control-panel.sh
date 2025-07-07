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



#----------------------------------------------------------------------------------
# Start Main Script

# Return to /usr/src
cd /usr/src

# phpSysinfo
# Remove existing phpSysinfo directory if it exists
if [[ -d "/var/www/admin/enginescript/phpsysinfo" ]]; then
  rm -rf /var/www/admin/enginescript/phpsysinfo
fi

# Clone phpSysinfo
git clone --depth 1 https://github.com/phpsysinfo/phpsysinfo.git /var/www/admin/enginescript/phpsysinfo
cp -rf /usr/local/bin/enginescript/config/var/www/admin/phpsysinfo/phpsysinfo.ini /var/www/admin/enginescript/phpsysinfo/phpsysinfo.ini
sed -i "s|SEDPHPVER|${PHP_VER}|g" /var/www/admin/enginescript/phpsysinfo/phpsysinfo.ini

# PHPinfo.php
mkdir -p /var/www/admin/enginescript/phpinfo
echo "<?php phpinfo(); ?>" > /var/www/admin/enginescript/phpinfo/index.php

# Admin Control Panel
cp -a /usr/local/bin/enginescript/config/var/www/admin/control-panel/. /var/www/admin/enginescript/

# Substitute frontend dependency versions
sed -i "s|{CHARTJS_VER}|${CHARTJS_VER}|g" /var/www/admin/enginescript/index.html
sed -i "s|{FONTAWESOME_VER}|${FONTAWESOME_VER}|g" /var/www/admin/enginescript/index.html

# Ensure API file is in the correct location for nginx routing
# The nginx config expects /enginescript/api.php for API calls
# Keep the original api.php in place for direct access

# Download and install official Tiny File Manager from GitHub
echo "Installing official Tiny File Manager from GitHub..."
TFM_DIR="/var/www/admin/enginescript/tinyfilemanager"
TFM_ZIP_URL="https://github.com/prasathmani/tinyfilemanager/archive/refs/tags/${TINYFILEMANAGER_VER}.tar.gz"
TFM_ZIP_FILE="/tmp/tinyfilemanager-${TINYFILEMANAGER_VER}.tar.gz"

# Remove existing TFM directory if it exists
if [[ -d "$TFM_DIR" ]]; then
    rm -rf "$TFM_DIR"
fi

# Create TFM directory
mkdir -p "$TFM_DIR"

# Download and extract TFM with error handling
if curl -fsSL --connect-timeout 30 --max-time 60 "${TFM_ZIP_URL}" -o "${TFM_ZIP_FILE}"; then
    if tar -xzf "${TFM_ZIP_FILE}" -C /tmp/; then
        # Copy files from extracted directory to our target directory
        cp -r /tmp/tinyfilemanager-${TINYFILEMANAGER_VER}/* "$TFM_DIR/"
        
        # Copy our custom configuration file
        if [[ -f "/usr/local/bin/enginescript/config/var/www/admin/tinyfilemanager/config.php" ]]; then
            cp /usr/local/bin/enginescript/config/var/www/admin/tinyfilemanager/config.php "$TFM_DIR/"
        fi
        
        # Set proper permissions
        find "$TFM_DIR" -type f -name "*.php" -exec chmod 644 {} \;
        find "$TFM_DIR" -type f -name "*.md" -exec chmod 644 {} \;
        find "$TFM_DIR" -type f -name "*.txt" -exec chmod 644 {} \;
        find "$TFM_DIR" -type d -exec chmod 755 {} \;
        chmod 755 "$TFM_DIR"
        
        # Clean up
        rm -f "${TFM_ZIP_FILE}"
        rm -rf /tmp/tinyfilemanager-${TINYFILEMANAGER_VER}
        
        echo "✓ Official Tiny File Manager v${TINYFILEMANAGER_VER} installed successfully"
        echo "  - Location: $TFM_DIR"
        echo "  - Access URL: /enginescript/tinyfilemanager/tinyfilemanager.php"
        echo "  - Default login: admin/admin"
    else
        echo "⚠ Warning: Failed to extract Tiny File Manager archive"
    fi
else
    echo "⚠ Warning: Failed to download Tiny File Manager from GitHub"
fi

# Create /etc/enginescript directory if it doesn't exist
if [[ ! -d "/etc/enginescript" ]]; then
    echo "Creating EngineScript configuration directory..."
    mkdir -p /etc/enginescript
    chmod 755 /etc/enginescript
    chown -R www-data:www-data /var/www/admin/enginescript
    chown -R www-data:www-data /etc/enginescript

    echo "✓ EngineScript configuration directory created"
fi

# Create Uptime Robot configuration file if it doesn't exist
if [[ ! -f "/etc/enginescript/uptimerobot.conf" ]]; then
    cp /usr/local/bin/enginescript/config/etc/enginescript/uptimerobot.conf /etc/enginescript/uptimerobot.conf
    chmod 600 /etc/enginescript/uptimerobot.conf
    chown -R www-data:www-data /etc/enginescript/uptimerobot.conf
fi

# Remove Adminer tool card if INSTALL_ADMINER=0
if [[ "${INSTALL_ADMINER}" -eq 0 ]]; then
    sed -i '/<div class="tool-card" data-tool="adminer" id="adminer-tool">/,/<\/div>/d' "/var/www/admin/enginescript/index.html"
fi

# Set Permissions
find /var/www/admin/enginescript -type d -print0 | sudo xargs -0 chmod 0755
find /var/www/admin/enginescript -type f -print0 | sudo xargs -0 chmod 0644
chown -R www-data:www-data /var/www/admin/enginescript

# Update configuration files from main credentials file
echo "Updating configuration files with user credentials..."
/usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh

# Return to /usr/src
cd /usr/src
