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

# Prompt for EngineScript Update
if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
    /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> /tmp/enginescript_install_errors.log
else
    echo "Skipping EngineScript update."
fi

# Accept target version from argument (used by menu) or fall back to variables + override
if [[ -n "${1}" ]]; then
    NEW_PHP_VER="${1}"
else
    NEW_PHP_VER="${PHP_VER}"
fi

# Auto-detect currently installed PHP-FPM version
OLD_PHP_VER=""
for ver in 8.1 8.2 8.3 8.4 8.5; do
    if [[ "${ver}" != "${NEW_PHP_VER}" ]] && dpkg -l | grep -q "php${ver}-fpm"; then
        OLD_PHP_VER="${ver}"
    fi
done

if [[ -z "${OLD_PHP_VER}" ]]; then
    # Check if target version is already installed
    if dpkg -l | grep -q "php${NEW_PHP_VER}-fpm"; then
        echo "PHP ${NEW_PHP_VER} is already installed. Nothing to upgrade."
        exit 0
    else
        echo "No existing PHP-FPM installation detected. Use php-install.sh for fresh installs."
        exit 1
    fi
fi

echo ""
echo "============================================================="
echo ""
echo "PHP Upgrade: Migrating from PHP ${OLD_PHP_VER} to PHP ${NEW_PHP_VER}"
echo ""
echo "============================================================="
echo ""

echo "Detected PHP ${OLD_PHP_VER} installation. Proceeding with upgrade..."

# Stop old PHP service
echo "Stopping PHP ${OLD_PHP_VER} service..."
systemctl stop "php${OLD_PHP_VER}-fpm" 2>/dev/null || true

# Install new PHP version
echo "Installing PHP ${NEW_PHP_VER}..."

# Define the PHP packages to install
php_packages="php${NEW_PHP_VER}
php${NEW_PHP_VER}-bcmath
php${NEW_PHP_VER}-common
php${NEW_PHP_VER}-curl
php${NEW_PHP_VER}-fpm
php${NEW_PHP_VER}-gd
php${NEW_PHP_VER}-imagick
php${NEW_PHP_VER}-intl
php${NEW_PHP_VER}-mbstring
php${NEW_PHP_VER}-mysql
php${NEW_PHP_VER}-redis
php${NEW_PHP_VER}-ssh2
php${NEW_PHP_VER}-xml
php${NEW_PHP_VER}-zip"

# PHP 8.5+ has opcache built-in; older versions need the separate package
if [[ "$(echo "${NEW_PHP_VER} < 8.5" | bc -l)" -eq 1 ]]; then
    php_packages="${php_packages}
php${NEW_PHP_VER}-opcache"
fi

# Install the packages with error checking
apt install -qy $php_packages || {
    echo "Error: Unable to install PHP ${NEW_PHP_VER} packages. Exiting..."
    exit 1
}

# Install expanded PHP packages if enabled
if [[ "$INSTALL_EXPANDED_PHP" == "1" ]]; then
    echo "Installing expanded PHP ${NEW_PHP_VER} packages..."
    expanded_php_packages="php${NEW_PHP_VER}-soap
php${NEW_PHP_VER}-sqlite3"

    apt install -qy $expanded_php_packages || {
        echo "Error: Unable to install expanded PHP ${NEW_PHP_VER} packages. Exiting..."
        exit 1
    }
fi

# Logrotate
if [[ -f "/etc/logrotate.d/php${NEW_PHP_VER}-fpm" ]]; then
    sed -i "s|rotate 12|rotate 5|g" "/etc/logrotate.d/php${NEW_PHP_VER}-fpm"
fi

# Backup PHP config
/usr/local/bin/enginescript/scripts/functions/backup/php-backup.sh

# Update PHP config with the latest EngineScript settings
/usr/local/bin/enginescript/scripts/update/php-config-update.sh

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

# Update php-fpm.conf
if [[ -f "/etc/nginx/globals/php-fpm.conf" ]]; then
    sed -i "s|php${OLD_PHP_VER}-fpm|php${NEW_PHP_VER}-fpm|g" "/etc/nginx/globals/php-fpm.conf"
    sed -i "s|php${OLD_PHP_VER}|php${NEW_PHP_VER}|g" "/etc/nginx/globals/php-fpm.conf"
fi

# Update all nginx site configurations
for config_file in /etc/nginx/sites-available/*; do
    if [[ -f "$config_file" ]]; then
        sed -i "s|php${OLD_PHP_VER}-fpm|php${NEW_PHP_VER}-fpm|g" "$config_file"
        sed -i "s|php${OLD_PHP_VER}|php${NEW_PHP_VER}|g" "$config_file"
    fi
done

# Update phpSysInfo configuration
if [[ -f "/var/www/admin/tools/phpsysinfo/phpsysinfo.ini" ]]; then
    echo "Updating phpSysInfo configuration..."
    sed -i "s|php${OLD_PHP_VER}|php${NEW_PHP_VER}|g" "/var/www/admin/tools/phpsysinfo/phpsysinfo.ini"
fi

# Update admin control panel API configuration
if [[ -f "/var/www/admin/control-panel/api.php" ]]; then
    echo "Updating admin control panel API configuration..."
    sed -i "s|php${OLD_PHP_VER}-fpm|php${NEW_PHP_VER}-fpm|g" "/var/www/admin/control-panel/api.php"
    sed -i "s|php${OLD_PHP_VER}|php${NEW_PHP_VER}|g" "/var/www/admin/control-panel/api.php"
fi

# Start new PHP service
echo "Starting PHP ${NEW_PHP_VER} service..."
systemctl enable "php${NEW_PHP_VER}-fpm"
systemctl start "php${NEW_PHP_VER}-fpm"

# Reload Nginx to pick up the new PHP configuration
echo "Reloading Nginx configuration..."
systemctl reload nginx

# PHP Service Check
STATUS="$(systemctl is-active "php${NEW_PHP_VER}-fpm")"
if [[ "${STATUS}" == "active" ]]; then
    echo "PASSED: PHP ${NEW_PHP_VER} is running."
    echo "PHP=1" >> /var/log/EngineScript/install-log.log
else
    echo "FAILED: PHP ${NEW_PHP_VER} not running. Please diagnose this issue before proceeding."
    exit 1
fi

# Remove old PHP version
echo "Removing PHP ${OLD_PHP_VER} installation..."

# Stop and disable old PHP service
systemctl stop "php${OLD_PHP_VER}-fpm" 2>/dev/null || true
systemctl disable "php${OLD_PHP_VER}-fpm" 2>/dev/null || true

# Remove old PHP packages
apt purge -y php${OLD_PHP_VER}* 2>/dev/null || true

# Remove old PHP configuration directory
rm -rf "/etc/php/${OLD_PHP_VER}" 2>/dev/null || true

# Remove old PHP logrotate configuration
rm -f "/etc/logrotate.d/php${OLD_PHP_VER}-fpm" 2>/dev/null || true

# Archive old log
if [[ -f "/var/log/php/php${OLD_PHP_VER}-fpm.log" ]]; then
    mv "/var/log/php/php${OLD_PHP_VER}-fpm.log" "/var/log/php/php${OLD_PHP_VER}-fpm.log.old" 2>/dev/null || true
fi

echo "PHP ${OLD_PHP_VER} has been removed."

# Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

# Display PHP version and modules
echo -e "\n\n=-=-=-=-=-=-=-=-=-\nPHP Info\n=-=-=-=-=-=-=-=-=-\n"
php -version
echo ""
php -m

# Final message
echo ""
echo ""
echo "============================================================="
echo ""
echo "PHP upgrade from ${OLD_PHP_VER} to ${NEW_PHP_VER} completed successfully."
echo ""
echo "Changes made:"
echo "  - Installed PHP ${NEW_PHP_VER} and extensions"
echo "  - Applied EngineScript configuration for PHP ${NEW_PHP_VER}"
echo "  - Updated Nginx configuration"
echo "  - Removed PHP ${OLD_PHP_VER} installation"
echo ""
echo "============================================================="
echo ""
