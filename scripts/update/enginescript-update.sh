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

# Return to /usr/src
cd /usr/src

# --------------------------------------------------------
# Update EngineScript

# Determine which branch to use based on TEST_MODE setting
if [[ "${TEST_MODE}" == "1" ]]; then
    ENGINESCRIPT_BRANCH="update-software-versions"
    echo "TEST_MODE enabled: Updating from development branch (update-software-versions)"
else
    ENGINESCRIPT_BRANCH="master"
    echo "Updating from production branch (master)"
fi

# Copy EngineScript
cd /usr/local/bin/enginescript
echo "Fetching ${ENGINESCRIPT_BRANCH} branch..."
git fetch origin "${ENGINESCRIPT_BRANCH}"
git checkout -f "${ENGINESCRIPT_BRANCH}"
git reset --hard FETCH_HEAD

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
echo "${BOLD}EngineScript has been updated${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""


# --------------------------------------------------------
# Check Installation Completion Status
verify_installation_completion "EngineScript Update"

echo "============================================================="
echo "Installation Verification Complete - Proceeding with Updates"
echo "============================================================="
echo ""


# --------------------------------------------------------
# Updating files from previous versions
/usr/local/bin/enginescript/scripts/functions/auto-upgrade/normal-auto-upgrade.sh
/usr/local/bin/enginescript/scripts/functions/auto-upgrade/emergency-auto-upgrade.sh


# --------------------------------------------------------
# Update EngineScript Frontend

# Admin Control Panel
/usr/local/bin/enginescript/scripts/install/tools/frontend/admin-control-panel-install.sh

# Install phpinfo
/usr/local/bin/enginescript/scripts/install/tools/frontend/phpinfo-install.sh

# Install phpSysinfo
/usr/local/bin/enginescript/scripts/install/tools/frontend/phpsysinfo-install.sh

# Install Tiny File Manager
/usr/local/bin/enginescript/scripts/install/tools/frontend/tiny-file-manager-install.sh

# Install UptimeRobot API
/usr/local/bin/enginescript/scripts/install/tools/frontend/uptimerobot-api-install.sh

# Update configuration files from main credentials file
echo "Updating configuration files with user credentials..."
/usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh

# Set permissions for EngineScript frontend directories
set_enginescript_frontend_permissions

# ---------------------------------------------------------
# Update EngineScript plugins

# Update both EngineScript plugins for each site in sites.sh
SITES_FILE="/home/EngineScript/sites-list/sites.sh"
if [[ -f "$SITES_FILE" ]]; then
  # shellcheck source=/home/EngineScript/sites-list/sites.sh
  source "$SITES_FILE"
  for SITE in "${SITES[@]}"; do
    # Remove quotes from domain name if present
    DOMAIN=$(echo "$SITE" | tr -d '"')
    WP_PLUGIN_DIR="/var/www/sites/${DOMAIN}/html/wp-content/plugins"
    if [[ -d "$WP_PLUGIN_DIR" ]]; then
      # Only update EngineScript custom plugins if the option is enabled
      if [[ "${INSTALL_ENGINESCRIPT_PLUGINS}" == "1" ]]; then
        # Update the two custom EngineScript plugins:
        
        # 1. Simple Site Exporter plugin
        echo "Updating Simple Site Exporter plugin for $DOMAIN..."
        mkdir -p "/tmp/sse-plugin-update"
        if wget -q "https://github.com/EngineScript/Simple-WP-Site-Exporter/releases/download/v${SSE_PLUGIN_VER}/simple-wp-site-exporter-${SSE_PLUGIN_VER}.zip" -O "/tmp/sse-plugin-update/simple-wp-site-exporter-${SSE_PLUGIN_VER}.zip" 2>/dev/null; then
          # Verify the downloaded file is a valid zip
          if unzip -t "/tmp/sse-plugin-update/simple-wp-site-exporter-${SSE_PLUGIN_VER}.zip" >/dev/null 2>&1; then
            unzip -q -o "/tmp/sse-plugin-update/simple-wp-site-exporter-${SSE_PLUGIN_VER}.zip" -d "$WP_PLUGIN_DIR/"
            echo "Simple Site Exporter plugin updated successfully for $DOMAIN"
          else
            echo "Warning: Downloaded Simple Site Exporter plugin file is corrupted for $DOMAIN"
          fi
        else
          echo "Warning: Failed to download Simple Site Exporter plugin for $DOMAIN"
        fi
        rm -rf "/tmp/sse-plugin-update"
        
        # 2. Simple WP Optimizer plugin
        echo "Updating Simple WP Optimizer plugin for $DOMAIN..."
        mkdir -p "/tmp/swpo-plugin-update"
        if wget -q "https://github.com/EngineScript/Simple-WP-Optimizer/releases/download/v${SWPO_PLUGIN_VER}/simple-wp-optimizer-${SWPO_PLUGIN_VER}.zip" -O "/tmp/swpo-plugin-update/simple-wp-optimizer-${SWPO_PLUGIN_VER}.zip" 2>/dev/null; then
          # Verify the downloaded file is a valid zip
          if unzip -t "/tmp/swpo-plugin-update/simple-wp-optimizer-${SWPO_PLUGIN_VER}.zip" >/dev/null 2>&1; then
            unzip -q -o "/tmp/swpo-plugin-update/simple-wp-optimizer-${SWPO_PLUGIN_VER}.zip" -d "$WP_PLUGIN_DIR/"
            echo "Simple WP Optimizer plugin updated successfully for $DOMAIN"
          else
            echo "Warning: Downloaded Simple WP Optimizer plugin file is corrupted for $DOMAIN"
          fi
        else
          echo "Warning: Failed to download Simple WP Optimizer plugin for $DOMAIN"
        fi
        rm -rf "/tmp/swpo-plugin-update"
        
        # Set permissions for both plugins (only if they exist)
        if [[ -d "$WP_PLUGIN_DIR/simple-site-exporter" ]]; then
          chown -R www-data:www-data "$WP_PLUGIN_DIR/simple-site-exporter"
          find "$WP_PLUGIN_DIR/simple-site-exporter" -type d -exec chmod 755 {} \;
          find "$WP_PLUGIN_DIR/simple-site-exporter" -type f -exec chmod 644 {} \;
        fi
        if [[ -d "$WP_PLUGIN_DIR/simple-wp-optimizer" ]]; then
          chown -R www-data:www-data "$WP_PLUGIN_DIR/simple-wp-optimizer"
          find "$WP_PLUGIN_DIR/simple-wp-optimizer" -type d -exec chmod 755 {} \;
          find "$WP_PLUGIN_DIR/simple-wp-optimizer" -type f -exec chmod 644 {} \;
        fi
      else
        echo "Skipping EngineScript custom plugins update for $DOMAIN (disabled in config)..."
      fi
    else
      echo "Warning: Plugin directory $WP_PLUGIN_DIR does not exist for site $DOMAIN"
    fi
  done
else
  echo "Warning: SITES file $SITES_FILE not found. Skipping plugin updates for sites."
fi

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}EngineScript has been updated${NORMAL}"
echo ""
echo "Branch: ${ENGINESCRIPT_BRANCH}"
echo ""
echo "============================================================="
echo ""
echo ""