#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Return to /usr/src
return_to_src

# --fetched: this copy was started by the previous step, after fetching the new version
# --scheduled: started by the daily maintenance job rather than by hand
FETCHED=0
SCHEDULED=0
for arg in "$@"; do
    case "${arg}" in
        --fetched) FETCHED=1 ;;
        --scheduled) SCHEDULED=1 ;;
    esac
done

# --------------------------------------------------------
# Update EngineScript

# Determine which branch to use based on TEST_MODE setting
if [[ "${TEST_MODE}" == "1" ]]; then
    ENGINESCRIPT_BRANCH="update-software-versions"
else
    ENGINESCRIPT_BRANCH="master"
fi

# Copy EngineScript, then run the new copy of this script for the rest of the update (--fetched).
# Bash keeps running the text of the file it started with, and the shared functions sourced
# above are the old ones, so without the restart an update would run the previous version's steps.
if [[ "${FETCHED}" != "1" ]]; then
    if [[ "${TEST_MODE}" == "1" ]]; then
        echo "TEST_MODE enabled: Updating from development branch (update-software-versions)"
    else
        echo "Updating from production branch (master)"
    fi
    cd /usr/local/bin/enginescript || { echo "Error: Failed to change to /usr/local/bin/enginescript" >&2; exit 1; }
    echo "Fetching ${ENGINESCRIPT_BRANCH} branch..."
    # Stop when the fetch fails: FETCH_HEAD would still name the previous fetch, which may be the
    # other branch if TEST_MODE changed since. After a successful fetch it names the new commit.
    if ! git fetch origin "${ENGINESCRIPT_BRANCH}" 2>> /tmp/enginescript_install_errors.log; then
        print_last_errors
        echo "Error: Could not fetch the ${ENGINESCRIPT_BRANCH} branch from GitHub. EngineScript was not updated." >&2
        exit 1
    fi
    if ! git checkout -f -B "${ENGINESCRIPT_BRANCH}" FETCH_HEAD 2>> /tmp/enginescript_install_errors.log; then
        print_last_errors
        echo "Error: Could not switch EngineScript to the fetched ${ENGINESCRIPT_BRANCH} branch. EngineScript was not updated." >&2
        exit 1
    fi
    print_last_errors
    debug_pause "EngineScript Git Pull"

    # The checkout has LF line ends (.gitattributes) and executable scripts (their mode in git);
    # the daily permissions job puts them back if something changes them

    exec bash /usr/local/bin/enginescript/scripts/update/enginescript-update.sh --fetched "$@"
fi

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
# One-time upgrades for servers installed by earlier versions (each runs once per server)
/usr/local/bin/enginescript/scripts/functions/auto-upgrade/normal-auto-upgrade.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Auto-Upgrades"

# Server settings that follow EngineScript's files (cron jobs, logrotate, kernel settings).
# A scheduled update syncs them only when it fetched a new version; a manual update always does.
if [[ "${SCHEDULED}" == "1" ]]; then
    /usr/local/bin/enginescript/scripts/functions/auto-upgrade/sync-server-config.sh 2>> /tmp/enginescript_install_errors.log
else
    /usr/local/bin/enginescript/scripts/functions/auto-upgrade/sync-server-config.sh --force 2>> /tmp/enginescript_install_errors.log
fi
print_last_errors
debug_pause "Server Settings Sync"


# --------------------------------------------------------
# Update EngineScript Frontend

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

# Admin Control Panel - replace with the new version
# The installer builds the new panel beside the running one and swaps it in only when it is
# complete: files the new version no longer has go away, and a failed update leaves the
# running panel as it was. Admin tools (phpMyAdmin, TinyFileManager, phpSysInfo, Adminer,
# phpinfo) are stored in /var/www/admin/tools/ and are NOT affected by updates.
/usr/local/bin/enginescript/scripts/install/tools/frontend/admin-control-panel-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Admin Control Panel Update"

# Tiny File Manager is installed once; its EngineScript configuration follows each update
if [[ -d "${TOOLS_DIR}/tinyfilemanager" ]]; then
    cp -f /usr/local/bin/enginescript/config/var/www/admin/tools/tinyfilemanager/config.php "${TOOLS_DIR}/tinyfilemanager/config.php" 2>> /tmp/enginescript_install_errors.log
    print_last_errors
fi

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
        if curl -fsSL --proto '=https' "https://github.com/EngineScript/enginescript-site-exporter/releases/download/v${ES_SE_PLUGIN_VER}/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" -o "/tmp/es-se-plugin-update/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" 2>/dev/null; then
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
        if curl -fsSL --proto '=https' "https://github.com/EngineScript/enginescript-site-optimizer/releases/download/v${ES_SO_PLUGIN_VER}/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" -o "/tmp/es-so-plugin-update/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" 2>/dev/null; then
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
          set_www_data_tree "$WP_PLUGIN_DIR/enginescript-site-exporter"
        fi
        if [[ -d "$WP_PLUGIN_DIR/enginescript-site-optimizer" ]]; then
          set_www_data_tree "$WP_PLUGIN_DIR/enginescript-site-optimizer"
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