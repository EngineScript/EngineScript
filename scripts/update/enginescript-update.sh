#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Return to /usr/src
return_to_src

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
cd /usr/local/bin/enginescript || { echo "Error: Failed to change to /usr/local/bin/enginescript" >&2; exit 1; }
echo "Fetching ${ENGINESCRIPT_BRANCH} branch..."
git fetch origin "${ENGINESCRIPT_BRANCH}" 2>> /tmp/enginescript_install_errors.log
git checkout -f "${ENGINESCRIPT_BRANCH}" 2>> /tmp/enginescript_install_errors.log
git reset --hard FETCH_HEAD 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "EngineScript Git Pull"

# Convert line endings
dos2unix /usr/local/bin/enginescript/*

# Set directory and file permissions to 755
find /usr/local/bin/enginescript \( -type d -o -type f \) -exec chmod 755 {} \;

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
/usr/local/bin/enginescript/scripts/functions/auto-upgrade/normal-auto-upgrade.sh 2>> /tmp/enginescript_install_errors.log
/usr/local/bin/enginescript/scripts/functions/auto-upgrade/emergency-auto-upgrade.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Auto-Upgrades"


# --------------------------------------------------------
# Update EngineScript Frontend

# Safety Check: Verify we're only wiping the control-panel directory
# This prevents accidental deletion of admin tools (phpMyAdmin, etc.)
CONTROL_PANEL_DIR="/var/www/admin/control-panel"
TOOLS_DIR="/var/www/admin/tools"

# Verify tools directory exists and is not empty (contains user configurations)
if [[ -d "$TOOLS_DIR" ]]; then
    TOOLS_COUNT=$(find "$TOOLS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    if [[ "$TOOLS_COUNT" -gt 0 ]]; then
        echo "✓ Admin tools directory verified: $TOOLS_COUNT tool(s) found in $TOOLS_DIR"
        echo "  Tools will NOT be affected by this update."
    fi
else
    echo "ℹ Admin tools directory not found. Creating..."
    mkdir -p "$TOOLS_DIR"
fi

# Admin Control Panel - Remove old files and replace with new version
# NOTE: Only the control-panel directory is wiped on updates.
# Admin tools (phpMyAdmin, TinyFileManager, phpSysInfo, Adminer, phpinfo)
# are stored in /var/www/admin/tools/ and are NOT affected by updates.
echo "Cleaning up old Admin Control Panel files..."

# Safety: Double-check we're targeting the correct directory
if [[ "$CONTROL_PANEL_DIR" == "/var/www/admin/control-panel" ]]; then
    rm -rf "${CONTROL_PANEL_DIR:?}"/*
else
    echo "ERROR: Control panel directory path mismatch. Aborting for safety."
    exit 1
fi

/usr/local/bin/enginescript/scripts/install/tools/frontend/admin-control-panel-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Admin Control Panel Update"

# Update configuration files from main credentials file
echo "Updating configuration files with user credentials..."
/usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Config Files Update"

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
        
        # 1. EngineScript Site Exporter plugin
        echo "Updating EngineScript Site Exporter plugin for $DOMAIN..."
        mkdir -p "/tmp/es-se-plugin-update"
        if wget -q "https://github.com/EngineScript/enginescript-site-exporter/releases/download/v${ES_SE_PLUGIN_VER}/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" -O "/tmp/es-se-plugin-update/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" 2>/dev/null; then
          # Verify the downloaded file is a valid zip
          if unzip -t "/tmp/es-se-plugin-update/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" >/dev/null 2>&1; then
            unzip -q -o "/tmp/es-se-plugin-update/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" -d "$WP_PLUGIN_DIR/"
            echo "EngineScript Site Exporter plugin updated successfully for $DOMAIN"
          else
            echo "Warning: Downloaded EngineScript Site Exporter plugin file is corrupted for $DOMAIN"
          fi
        else
          echo "Warning: Failed to download EngineScript Site Exporter plugin for $DOMAIN"
        fi
        rm -rf "/tmp/es-se-plugin-update"
        
        # 2. EngineScript Site Optimizer plugin
        echo "Updating EngineScript Site Optimizer plugin for $DOMAIN..."
        mkdir -p "/tmp/es-so-plugin-update"
        if wget -q "https://github.com/EngineScript/enginescript-site-optimizer/releases/download/v${ES_SO_PLUGIN_VER}/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" -O "/tmp/es-so-plugin-update/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" 2>/dev/null; then
          # Verify the downloaded file is a valid zip
          if unzip -t "/tmp/es-so-plugin-update/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" >/dev/null 2>&1; then
            unzip -q -o "/tmp/es-so-plugin-update/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" -d "$WP_PLUGIN_DIR/"
            echo "EngineScript Site Optimizer plugin updated successfully for $DOMAIN"
          else
            echo "Warning: Downloaded EngineScript Site Optimizer plugin file is corrupted for $DOMAIN"
          fi
        else
          echo "Warning: Failed to download EngineScript Site Optimizer plugin for $DOMAIN"
        fi
        rm -rf "/tmp/es-so-plugin-update"
        
        # Set permissions for both plugins (only if they exist)
        if [[ -d "$WP_PLUGIN_DIR/enginescript-site-exporter" ]]; then
          chown -R www-data:www-data "$WP_PLUGIN_DIR/enginescript-site-exporter"
          find "$WP_PLUGIN_DIR/enginescript-site-exporter" -type d -exec chmod 755 {} \;
          find "$WP_PLUGIN_DIR/enginescript-site-exporter" -type f -exec chmod 644 {} \;
        fi
        if [[ -d "$WP_PLUGIN_DIR/enginescript-site-optimizer" ]]; then
          chown -R www-data:www-data "$WP_PLUGIN_DIR/enginescript-site-optimizer"
          find "$WP_PLUGIN_DIR/enginescript-site-optimizer" -type d -exec chmod 755 {} \;
          find "$WP_PLUGIN_DIR/enginescript-site-optimizer" -type f -exec chmod 644 {} \;
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
print_last_errors
debug_pause "EngineScript Plugins Update"

# Certificates of existing sites: reload Nginx after each renewal
migrate_acme_reload_commands 2>> /tmp/enginescript_install_errors.log
print_last_errors

# PHP-FPM log: move existing installs back to the package default, which logrotate covers
migrate_php_fpm_log_path 2>> /tmp/enginescript_install_errors.log
print_last_errors

# PHP: igbinary installed by name (Redis Object Cache's serializer), not only as a dependency
ensure_php_igbinary 2>> /tmp/enginescript_install_errors.log
print_last_errors

# PHP: turn off session upload progress (security; WordPress does not use it)
migrate_php_upload_progress 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Backups: one scheduler cron job in place of the separate backup jobs
install_backup_cron 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Redis: 128 databases, and every site on its own database number
migrate_redis_databases 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Redis: cache flushes free memory in the background
migrate_redis_lazy_user_flush 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Kernel settings: the audited sysctl file, applied live (a reboot completes the rest)
install_enginescript_sysctl 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Kernel Samepage Merging: nothing on these servers can use it
disable_ksm 2>> /tmp/enginescript_install_errors.log
print_last_errors

# Transparent Huge Pages: switched off before the services start
if [[ -f /etc/systemd/system/disable-thp.service ]]; then
  cp -f /usr/local/bin/enginescript/config/etc/systemd/system/disable-thp.service /etc/systemd/system/disable-thp.service
  chmod 644 /etc/systemd/system/disable-thp.service
  systemctl daemon-reload
fi

# Shared tuning plan: re-tune PHP-FPM, Redis, MariaDB, and Nginx when the server has no plan
# yet, the plan format changed, or RAM or the CPU count changed (a resized droplet)
if tuning_needs_replan; then
  echo "Re-tuning services for this server's RAM and CPUs..."
  /usr/local/bin/enginescript/scripts/update/retune-services.sh 2>> /tmp/enginescript_install_errors.log
  print_last_errors
fi

# Warn when the installed PHP version is no longer supported
INSTALLED_PHP_VER="$(get_installed_php_version)"
if [[ -n "${INSTALLED_PHP_VER}" ]] && ! printf '%s\n' "${SUPPORTED_PHP_VERSIONS[@]}" | grep -qxF "${INSTALLED_PHP_VER}"; then
  echo ""
  echo "WARNING: PHP ${INSTALLED_PHP_VER} is no longer supported by EngineScript (supported: ${SUPPORTED_PHP_VERSIONS[*]})."
  echo "Switch to a supported version with: es.menu > Update Software > Switch PHP Version"
  echo ""
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