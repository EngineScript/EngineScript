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

# Prompt for EngineScript Update
if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
    /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> /tmp/enginescript_install_errors.log
else
    echo "Skipping EngineScript update."
fi
print_last_errors
debug_pause "EngineScript Update"

# Accept target version from argument (used by menu) or fall back to variables + override
if [[ -n "${1}" ]]; then
    NEW_PHP_VER="${1}"
else
    NEW_PHP_VER="${PHP_VER}"
fi

# Auto-detect currently installed PHP-FPM version
DPKG_LIST_OUTPUT="$(dpkg -l)"
OLD_PHP_VERS=()
for ver in "${SUPPORTED_PHP_VERSIONS[@]}"; do
    if [[ "${ver}" != "${NEW_PHP_VER}" ]] && grep -q "php${ver}-fpm" <<< "${DPKG_LIST_OUTPUT}"; then
        OLD_PHP_VERS+=("${ver}")
    fi
done

if [[ ${#OLD_PHP_VERS[@]} -eq 0 ]]; then
    # Check if target version is already installed
    if dpkg-query -W -f='${Status}' "php${NEW_PHP_VER}-fpm" 2>/dev/null | grep -q 'install ok installed'; then
        echo "PHP ${NEW_PHP_VER} is already installed. Nothing to upgrade."
        exit 0
    else
        echo "No existing PHP-FPM installation detected. Use php-install.sh for fresh installs."
        exit 1
    fi
fi

# Keep backward-compatible single-version variable for legacy downstream logic.
# Migration logic must use MIGRATION_SOURCE_PHP_VERS to ensure all detected old versions are handled.
OLD_PHP_VER="${OLD_PHP_VERS[0]}"
MIGRATION_SOURCE_PHP_VERS=("${OLD_PHP_VERS[@]}")

echo ""
echo "============================================================="
echo ""
echo "PHP Upgrade: Migrating to PHP ${NEW_PHP_VER} from detected old version(s): ${MIGRATION_SOURCE_PHP_VERS[*]}"
echo ""
echo "============================================================="
echo ""

echo "Detected PHP installation(s): ${MIGRATION_SOURCE_PHP_VERS[*]}"
echo "Proceeding with upgrade to PHP ${NEW_PHP_VER}..."

# Stop old PHP service(s)
for old_ver in "${MIGRATION_SOURCE_PHP_VERS[@]}"; do
    echo "Stopping PHP ${old_ver} service..."
    systemctl stop "php${old_ver}-fpm" 2>/dev/null || true
done

# Install new PHP version
echo "Installing PHP ${NEW_PHP_VER}..."

# Define the PHP packages to install
mapfile -t php_packages < <(get_php_packages_array "${NEW_PHP_VER}")

# Install the packages with error checking
apt install -qy "${php_packages[@]}" 2>> /tmp/enginescript_install_errors.log || {
    echo "Error: Unable to install PHP ${NEW_PHP_VER} packages. Exiting..."
    exit 1
}

# Install expanded PHP packages if enabled
if [[ "$INSTALL_EXPANDED_PHP" == "1" ]]; then
    echo "Installing expanded PHP ${NEW_PHP_VER} packages..."
    mapfile -t expanded_php_packages < <(get_expanded_php_packages_array "${NEW_PHP_VER}")

    apt install -qy "${expanded_php_packages[@]}" 2>> /tmp/enginescript_install_errors.log || {
        echo "Error: Unable to install expanded PHP ${NEW_PHP_VER} packages. Exiting..."
        exit 1
    }
fi
print_last_errors
debug_pause "PHP Package Installation"

# Logrotate
if [[ -f "/etc/logrotate.d/php${NEW_PHP_VER}-fpm" ]]; then
    sed -i "s|rotate 12|rotate 5|g" "/etc/logrotate.d/php${NEW_PHP_VER}-fpm"
fi

# Backup PHP config
/usr/local/bin/enginescript/scripts/functions/backup/php-backup.sh 2>> /tmp/enginescript_install_errors.log

# Update PHP config with the latest EngineScript settings
/usr/local/bin/enginescript/scripts/update/php-config-update.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "PHP Configuration"

# Create necessary directories and log files
mkdir -p /var/cache/opcache
mkdir -p /var/cache/php-sessions
mkdir -p /var/cache/wsdlcache
mkdir -p /var/log/opcache
mkdir -p /var/log/php

touch "/var/log/opcache/opcache.log"
touch "/var/log/php/php${NEW_PHP_VER}-fpm.log"

# Assign PHP Permissions
set_php_permissions

# Update Nginx configuration to use new PHP version
echo "Updating Nginx configuration for PHP ${NEW_PHP_VER}..."

# Shared sed expressions for PHP version migrations in nginx configs.
# These are printf-style templates: first %s = OLD_VER, second %s = NEW_PHP_VER.
SOCKET_EXPR='s|(unix:/run/php/)php%s-fpm(\.sock)|\1php%s-fpm\2|g'
FASTCGI_EXPR='s|(fastcgi_pass[[:space:]]+[^;]*php)%s(-fpm)|\1%s\2|g'

# Escape text for use in sed extended regex pattern fragments.
sed_escape_ere() {
    local text="$1"
    printf '%s' "$text" | sed -e 's/[][(){}.^$*+?|\\]/\\&/g'
    return $?
}

# Escape text for use in sed replacement fragments.
sed_escape_replacement() {
    local text="$1"
    printf '%s' "$text" | sed -e 's/[&\\]/\\&/g'
    return $?
}

# Update php-fpm.conf
if [[ -f "/etc/nginx/globals/php-fpm.conf" ]]; then
    for OLD_VER in "${MIGRATION_SOURCE_PHP_VERS[@]}"; do
        OLD_VER_ERE="$(sed_escape_ere "$OLD_VER")"
        NEW_PHP_VER_REPL="$(sed_escape_replacement "$NEW_PHP_VER")"
        sed -E -i \
            -e "$(printf "$SOCKET_EXPR" "$OLD_VER_ERE" "$NEW_PHP_VER_REPL")" \
            -e "$(printf "$FASTCGI_EXPR" "$OLD_VER_ERE" "$NEW_PHP_VER_REPL")" \
            "/etc/nginx/globals/php-fpm.conf"
    done
fi

# Update all nginx site configurations
for config_file in /etc/nginx/sites-available/*; do
    if [[ -f "$config_file" ]]; then
        for OLD_VER in "${MIGRATION_SOURCE_PHP_VERS[@]}"; do
            OLD_VER_ERE="$(sed_escape_ere "$OLD_VER")"
            NEW_PHP_VER_REPL="$(sed_escape_replacement "$NEW_PHP_VER")"
            sed -E -i -e "/^[[:space:]]*fastcgi_pass[[:space:]]+/$(printf "$FASTCGI_EXPR" "$OLD_VER_ERE" "$NEW_PHP_VER_REPL")" "$config_file"
        done
    fi
done

# Update phpSysInfo configuration
if [[ -f "/var/www/admin/tools/phpsysinfo/phpsysinfo.ini" ]]; then
    echo "Updating phpSysInfo configuration..."
    for OLD_VER in "${MIGRATION_SOURCE_PHP_VERS[@]}"; do
        sed -E -i "s|^([[:space:]]*[[:alnum:]_.-]+[[:space:]]*=[[:space:]]*.*)php${OLD_VER}(-fpm)?|\1php${NEW_PHP_VER}\2|g" "/var/www/admin/tools/phpsysinfo/phpsysinfo.ini"
    done
fi

# Update admin control panel API configuration
if [[ -f "/var/www/admin/control-panel/api.php" ]]; then
    echo "Updating admin control panel API configuration..."
    for OLD_VER in "${MIGRATION_SOURCE_PHP_VERS[@]}"; do
        sed -E -i "/(php-fpm|fastcgi_pass|sock(et)?|service)/ s|(php)${OLD_VER}(-fpm)?|\1${NEW_PHP_VER}\2|g" "/var/www/admin/control-panel/api.php"
    done
fi

# Start new PHP service
echo "Starting PHP ${NEW_PHP_VER} service..."
systemctl enable "php${NEW_PHP_VER}-fpm" 2>> /tmp/enginescript_install_errors.log
systemctl start "php${NEW_PHP_VER}-fpm" 2>> /tmp/enginescript_install_errors.log

# Reload Nginx to pick up the new PHP configuration
echo "Reloading Nginx configuration..."
systemctl reload nginx 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "PHP Service Start"

# PHP Service Check
STATUS="$(systemctl is-active "php${NEW_PHP_VER}-fpm")"
if [[ "${STATUS}" == "active" ]]; then
    echo "PASSED: PHP ${NEW_PHP_VER} is running."
    mkdir -p /etc/enginescript
    touch /etc/enginescript/install-state.conf
    if grep -q '^PHP=' /etc/enginescript/install-state.conf; then
        sed -i 's/^PHP=.*/PHP=1/' /etc/enginescript/install-state.conf
    else
        echo "PHP=1" >> /etc/enginescript/install-state.conf
    fi
else
    echo "FAILED: PHP ${NEW_PHP_VER} not running. Please diagnose this issue before proceeding."
    exit 1
fi

# Remove old PHP version(s)
echo "Removing old PHP installation(s)..."

for OLD_VER in "${OLD_PHP_VERS[@]}"; do
    echo "Removing PHP ${OLD_VER} installation..."

    # Stop and disable old PHP service
    systemctl stop "php${OLD_VER}-fpm" 2>/dev/null || true
    systemctl disable "php${OLD_VER}-fpm" 2>/dev/null || true

    # Remove old PHP packages
    apt purge -y "php${OLD_VER}*" 2>/dev/null || true

    # Remove old PHP configuration directory
    rm -rf "/etc/php/${OLD_VER}" 2>/dev/null || true

    # Remove old PHP logrotate configuration
    rm -f "/etc/logrotate.d/php${OLD_VER}-fpm" 2>/dev/null || true

    # Archive old log
    if [[ -f "/var/log/php/php${OLD_VER}-fpm.log" ]]; then
        mv "/var/log/php/php${OLD_VER}-fpm.log" "/var/log/php/php${OLD_VER}-fpm.log.old" 2>/dev/null || true
    fi

    echo "PHP ${OLD_VER} has been removed."
done

# Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh 2>> /tmp/enginescript_install_errors.log
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Cleanup"

# Display PHP version and modules
echo -e "\n\n=-=-=-=-=-=-=-=-=-\nPHP Info\n=-=-=-=-=-=-=-=-=-\n"
php --version
echo ""
php -m

# Final message
echo ""
echo ""
echo "============================================================="
echo ""
echo "PHP upgrade from ${MIGRATION_SOURCE_PHP_VERS[*]} to ${NEW_PHP_VER} completed successfully."
echo ""
echo "Changes made:"
echo "  - Installed PHP ${NEW_PHP_VER} and extensions"
echo "  - Applied EngineScript configuration for PHP ${NEW_PHP_VER}"
echo "  - Updated Nginx configuration"
echo "  - Removed PHP version(s): ${MIGRATION_SOURCE_PHP_VERS[*]}"
echo ""
echo "============================================================="
echo ""
