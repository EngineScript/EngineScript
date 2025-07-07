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

# Download Tiny File Manager for the file manager tool
echo "Downloading Tiny File Manager..."
TFM_URL="https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php"
TFM_FILE="/var/www/admin/enginescript/tinyfilemanager.php"

# Download TFM with error handling
if curl -fsSL --connect-timeout 30 --max-time 60 "${TFM_URL}" -o "${TFM_FILE}"; then
    chmod 644 "${TFM_FILE}"
    echo "Tiny File Manager downloaded successfully."
else
    echo "Warning: Failed to download Tiny File Manager. File manager will attempt auto-download on first access."
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

# Create File Manager configuration file if it doesn't exist
if [[ ! -f "/etc/enginescript/filemanager.conf" ]]; then
    echo "Creating File Manager configuration file..."
    cp /usr/local/bin/enginescript/config/etc/enginescript/filemanager.conf /etc/enginescript/filemanager.conf
    chmod 600 /etc/enginescript/filemanager.conf
    chown -R www-data:www-data /etc/enginescript/filemanager.conf
    echo "✓ File Manager configuration template created"
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
