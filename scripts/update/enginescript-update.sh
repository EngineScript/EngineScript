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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

cd /usr/local/bin/enginescript
git fetch origin master
git reset --hard origin/master

# Convert line endings
dos2unix /usr/local/bin/enginescript/*

# Set directory and file permissions to 755
find /usr/local/bin/enginescript -type d,f -exec chmod 755 {} \;

# Set ownership
chown -R root:root /usr/local/bin/enginescript

# Make shell scripts executable
find /usr/local/bin/enginescript -type f -iname "*.sh" -exec chmod +x {} \;

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}EngineScript has been updated.${NORMAL}"
echo ""
echo "This update includes:"
echo "    - EngineScript"
echo ""
echo "============================================================="
echo ""
echo ""

# Updating files from previous versions
/usr/local/bin/enginescript/scripts/functions/auto-upgrade/normal-auto-upgrade.sh
/usr/local/bin/enginescript/scripts/functions/auto-upgrade/emergency-auto-upgrade.sh

# Update both EngineScript plugins for each site in sites.sh
SITES_FILE="/home/EngineScript/sites-list/sites.sh"
if [ -f "$SITES_FILE" ]; then
  # shellcheck source=/home/EngineScript/sites-list/sites.sh
  source "$SITES_FILE"
  for SITE in "${SITES[@]}"; do
    DOMAIN=$(basename "$SITE")
    WP_PLUGIN_DIR="/var/www/sites/${DOMAIN}/html/wp-content/plugins"
    if [ -d "$WP_PLUGIN_DIR" ]; then
      # Only update EngineScript custom plugins if the option is enabled
      if [ "${INSTALL_ENGINESCRIPT_PLUGINS}" = 1 ]; then
        # Update the two custom EngineScript plugins:
        
        # 1. Simple Site Exporter plugin
        echo "Updating Simple Site Exporter plugin for $DOMAIN..."
        mkdir -p "/tmp/sse-plugin-update"
        wget -q "https://github.com/EngineScript/Simple-Site-Exporter/releases/latest/download/simple-site-exporter-enginescript.zip" -O "/tmp/sse-plugin-update/simple-site-exporter-enginescript.zip"
        unzip -q -o "/tmp/sse-plugin-update/simple-site-exporter-enginescript.zip" -d "$WP_PLUGIN_DIR/"
        rm -rf "/tmp/sse-plugin-update"
        
        # 2. Simple WP Optimizer plugin
        echo "Updating Simple WP Optimizer plugin for $DOMAIN..."
        cp -rf /usr/local/bin/enginescript/config/var/www/wordpress/plugins/simple-wp-optimizer-enginescript "$WP_PLUGIN_DIR/"
        
        # Set permissions for both plugins
        chown -R www-data:www-data "$WP_PLUGIN_DIR/simple-site-exporter-enginescript"
        chown -R www-data:www-data "$WP_PLUGIN_DIR/simple-wp-optimizer-enginescript"
        find "$WP_PLUGIN_DIR/simple-site-exporter-enginescript" -type d -exec chmod 755 {} \;
        find "$WP_PLUGIN_DIR/simple-site-exporter-enginescript" -type f -exec chmod 644 {} \;
        find "$WP_PLUGIN_DIR/simple-wp-optimizer-enginescript" -type d -exec chmod 755 {} \;
        find "$WP_PLUGIN_DIR/simple-wp-optimizer-enginescript" -type f -exec chmod 644 {} \;
      else
        echo "Skipping EngineScript custom plugins update for $DOMAIN (disabled in config)..."
      fi
    else
      echo "Warning: Plugin directory $WP_PLUGIN_DIR does not exist for site $SITE"
    fi
  done
else
  echo "Warning: SITES file $SITES_FILE not found. Skipping plugin updates for sites."
fi
